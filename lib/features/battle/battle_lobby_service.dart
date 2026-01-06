import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'battle_lobby_model.dart';

class BattleLobbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'battle_lobbies';

  DocumentReference<Map<String, dynamic>> _ref(String code) =>
      _db.collection(_collection).doc(code);

  String normalizeCode(String raw) {
    return raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .trim();
  }

  String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createLobby({
    required String userId,
    required List<String> questions,
  }) async {
    final q = List<String>.from(questions);
    if (q.length > 10) q.removeRange(10, q.length);

    for (int i = 0; i < 8; i++) {
      final code = _newCode();
      final ref = _ref(code);

      final snap = await ref.get();
      if (snap.exists) continue;

      await ref.set({
        'hostId': userId,
        'guestId': null,
        'status': 'waiting',
        'questions': q,
        'currentIndex': 0,
        'scores': {userId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,

        // phase 2 maps
        'answers': {},
        'locked': {},

        // ✅ options will be generated on startBattle (frozen for all questions)
        'options': {},
        // ✅ optional: prevents double-advance
        'lastAutoAdvancedIndex': -1,
      });

      return code;
    }
    throw Exception('Failed to create unique lobby code.');
  }

  Future<bool> joinLobby(String rawCode, String userId) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) return false;

    final ref = _ref(code);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      final hostId = (data['hostId'] ?? '') as String;
      final guestId = data['guestId'] as String?;

      if (status == 'started' || status == 'finished') return false;

      // ✅ block if someone else already joined
      if (guestId != null && guestId != userId) return false;

      final scores = Map<String, dynamic>.from((data['scores'] as Map?) ?? {});
      scores.putIfAbsent(hostId, () => 0);
      scores.putIfAbsent(userId, () => 0);

      tx.update(ref, {
        'guestId': userId,
        'status': 'active',
        'scores': scores,
      });

      return true;
    });
  }

  /// ✅ Host starts battle (active -> started) and freezes options for ALL questions.
  /// Pass a map: term -> meaning so we can build real MCQ options.
  Future<void> startBattle({
    required String rawCode,
    required Map<String, String> termToMeaning,
  }) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) throw Exception('Invalid lobby code.');

    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Lobby not found.');

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      final hostId = (data['hostId'] ?? '') as String;
      final guestId = data['guestId'] as String?;
      final questionsRaw = (data['questions'] as List?) ?? const <dynamic>[];
      final questions = questionsRaw.map((e) => e.toString()).toList();

      if (status != 'active') {
        throw Exception('Lobby not ready (need guest to join).');
      }
      if (guestId == null || guestId.isEmpty) {
        throw Exception('No guest joined yet.');
      }
      if (questions.isEmpty) {
        throw Exception('No questions in lobby.');
      }

      // Build options for ALL indices once
      final allMeanings = termToMeaning.values
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();

      if (allMeanings.length < 4) {
        throw Exception('Not enough meanings to generate options.');
      }

      final options = <String, List<String>>{};
      final rng = Random.secure();

      for (int i = 0; i < questions.length; i++) {
        final term = questions[i];
        final correct = (termToMeaning[term] ?? '').trim();
        if (correct.isEmpty) {
          // fallback: just pick some meanings, but still include something
          allMeanings.shuffle(rng);
          options['$i'] = allMeanings.take(4).toList();
          continue;
        }

        // pick 3 wrong meanings
        final wrongPool = allMeanings.where((m) => m != correct).toList();
        wrongPool.shuffle(rng);
        final wrong = wrongPool.take(3).toList();

        final opts = <String>[correct, ...wrong]..shuffle(rng);
        options['$i'] = opts;
      }

      tx.update(ref, {
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
        'currentIndex': 0,
        'scores': {hostId: 0, guestId: 0},
        'answers': {},
        'locked': {},
        'options': options,
        'lastAutoAdvancedIndex': -1,
      });
    });
  }

  Future<void> advanceQuestion(String rawCode) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Lobby not found.');

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      final questions = (data['questions'] as List? ?? const []);
      final idx = (data['currentIndex'] ?? 0) as int;

      if (status != 'started') return;

      final next = idx + 1;
      if (next >= questions.length) {
        tx.update(ref, {'status': 'finished'});
      } else {
        tx.update(ref, {'currentIndex': next});
      }
    });
  }

  /// ✅ Submit an answer + score + lock when both answered
  Future<void> submitAnswer({
    required String rawCode,
    required String userId,
    required int index,
    required String selected,
    required bool correct,
  }) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Lobby not found');

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      if (status != 'started') return;

      final hostId = (data['hostId'] ?? '') as String;
      final guestId = (data['guestId'] ?? '') as String;

      final answers = Map<String, dynamic>.from((data['answers'] as Map?) ?? {});
      final locked = Map<String, dynamic>.from((data['locked'] as Map?) ?? {});
      final scores = Map<String, dynamic>.from((data['scores'] as Map?) ?? {});

      if (locked['$index'] == true) return;

      final perIndex =
          Map<String, dynamic>.from((answers['$index'] as Map?) ?? {});
      final alreadyAnswered = perIndex.containsKey(userId);

      perIndex[userId] = {
        'selected': selected,
        'correct': correct,
        'at': FieldValue.serverTimestamp(),
      };
      answers['$index'] = perIndex;

      // ensure score keys exist
      if (hostId.isNotEmpty) scores.putIfAbsent(hostId, () => 0);
      if (guestId.isNotEmpty) scores.putIfAbsent(guestId, () => 0);

      // +1 only once per question if correct
      if (!alreadyAnswered && correct) {
        final cur = (scores[userId] ?? 0) as int;
        scores[userId] = cur + 1;
      }

      final bothAnswered = hostId.isNotEmpty &&
          guestId.isNotEmpty &&
          perIndex.containsKey(hostId) &&
          perIndex.containsKey(guestId);

      if (bothAnswered) {
        locked['$index'] = true;
      }

      tx.update(ref, {
        'answers': answers,
        'locked': locked,
        'scores': scores,
      });
    });
  }

  /// ✅ Safe auto-advance (call from UI when locked)
  /// Prevents double-advance using lastAutoAdvancedIndex + currentIndex check.
  Future<void> tryAutoAdvanceIfLocked(String rawCode) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      if (status != 'started') return;

      final idx = (data['currentIndex'] ?? 0) as int;
      final locked = Map<String, dynamic>.from((data['locked'] as Map?) ?? {});
      final lastAuto = (data['lastAutoAdvancedIndex'] ?? -1) as int;

      // only advance once per index
      if (lastAuto == idx) return;

      if (locked['$idx'] != true) return;

      final questions = (data['questions'] as List? ?? const []);
      final next = idx + 1;

      if (next >= questions.length) {
        tx.update(ref, {
          'status': 'finished',
          'lastAutoAdvancedIndex': idx,
        });
      } else {
        tx.update(ref, {
          'currentIndex': next,
          'lastAutoAdvancedIndex': idx,
        });
      }
    });
  }

  Stream<BattleLobby?> watchLobby(String rawCode) {
    final code = normalizeCode(rawCode);
    return _ref(code).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BattleLobby.fromDoc(doc);
    });
  }
}