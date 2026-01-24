import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'battle_lobby_model.dart';

class BattleLobbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'battle_lobbies';

  DocumentReference<Map<String, dynamic>> _ref(String code) =>
      _db.collection(_collection).doc(code);

  /// Normalize any user-entered lobby code (QR / typing / spaces)
  String normalizeCode(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
  }

  String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// ✅ Estimate server clock offset so all devices can align to server-based time.
  /// Returns: (serverNow - localNow)
  Future<Duration> getServerTimeOffset() async {
    final ref = _db.collection(_collection).doc('_time_sync');

    await ref.set({'ts': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    Timestamp? ts = snap.data()?['ts'] as Timestamp?;

    if (ts == null) {
      await Future.delayed(const Duration(milliseconds: 120));
      snap = await ref.get();
      ts = snap.data()?['ts'] as Timestamp?;
    }

    if (ts == null) return Duration.zero;

    final serverNow = ts.toDate();
    final localNow = DateTime.now();
    return serverNow.difference(localNow);
  }

  /// Host creates lobby (status=waiting)
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
        'status': 'waiting', // waiting -> active -> started -> finished
        'questions': q,
        'currentIndex': 0,
        'scores': {userId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,

        // Phase 2+ fields
        'answers': {}, // index -> uid -> {selected, correct, at}
        'locked': {},  // index -> true

        // frozen options for the whole game
        'options': {}, // index -> [4 options]

        // timer
        'timerSeconds': 10,
        'questionStartedAt': null,

        // sync start
        'battleStartsAt': null,
      });

      return code;
    }

    throw Exception('Failed to create unique lobby code.');
  }

  /// Guest joins lobby (waiting/active) -> sets guestId + status=active
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

      // can't join if already started/finished
      if (status == 'started' || status == 'finished') return false;

      // SAFE JOIN: block if someone else already joined
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

  /// Host starts battle (active -> started)
  /// ✅ Freezes options for ALL questions once.
  /// ✅ Sets a single shared battleStartsAt so both phones start together.
  Future<void> startBattle({
    required String rawCode,
    required Map<String, String> termToMeaning,
    int timerSeconds = 10,
    int startDelayMs = 900, // small buffer so both devices can navigate + start together
  }) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) throw Exception('Invalid lobby code.');

    final ref = _ref(code);

    // Host computes a server-synced start time
    final offset = await getServerTimeOffset();
    final serverNowApprox = DateTime.now().add(offset);
    final battleStartsAt = serverNowApprox.add(Duration(milliseconds: startDelayMs));

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Lobby not found.');

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      final hostId = (data['hostId'] ?? '') as String;
      final guestId = data['guestId'] as String?;
      final qRaw = (data['questions'] as List?) ?? const <dynamic>[];
      final questions = qRaw.map((e) => e.toString()).toList();

      if (status != 'active') {
        throw Exception('Lobby not ready (need guest to join).');
      }
      if (guestId == null || guestId.isEmpty) {
        throw Exception('No guest joined yet.');
      }
      if (questions.isEmpty) {
        throw Exception('No questions in lobby.');
      }

      // reset scores
      final scores = <String, dynamic>{hostId: 0, guestId: 0};

      // ✅ Build & freeze options for ALL questions once
      final options = <String, dynamic>{};

      // pool of meanings for wrong answers
      final allMeanings = termToMeaning.values
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();

      for (int i = 0; i < questions.length; i++) {
        final term = questions[i];
        final correct = (termToMeaning[term] ?? '').trim();

        // Build wrong pool excluding correct
        final wrongPool = allMeanings.where((m) => m != correct).toList()..shuffle();

        final wrongs = <String>[];
        for (final w in wrongPool) {
          if (wrongs.length >= 3) break;
          if (!wrongs.contains(w)) wrongs.add(w);
        }

        // If pool is too small, pad (keeps UI from breaking)
        while (wrongs.length < 3) {
          wrongs.add('Not sure 🤔');
        }

        final list = <String>[correct.isEmpty ? 'Unknown' : correct, ...wrongs];
        list.shuffle();

        options['$i'] = list;
      }

      tx.update(ref, {
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
        'currentIndex': 0,
        'scores': scores,

        'answers': {},
        'locked': {},

        'options': options,

        'timerSeconds': timerSeconds,

        // ✅ shared sync fields
        'battleStartsAt': Timestamp.fromDate(battleStartsAt),
        'questionStartedAt': Timestamp.fromDate(battleStartsAt),
      });
    });
  }

  /// Submit answer:
  /// - saves answers[index][uid]
  /// - increments score once if correct
  /// - locks when both answered
  /// - auto-advances when both answered ✅
  Future<void> submitAnswer({
    required String rawCode,
    required String userId,
    required int index,
    required String selected,
    required String correctAnswer,
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

      final questions = (data['questions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      final currentIndex = (data['currentIndex'] ?? 0) as int;

      final answers = Map<String, dynamic>.from((data['answers'] as Map?) ?? {});
      final locked = Map<String, dynamic>.from((data['locked'] as Map?) ?? {});

      if (locked['$index'] == true) return;

      final existingForIndex =
          Map<String, dynamic>.from((answers['$index'] as Map?) ?? {});
      final alreadyAnswered = existingForIndex.containsKey(userId);

      final isCorrect = selected.trim() == correctAnswer.trim();

      existingForIndex[userId] = {
        'selected': selected,
        'correct': isCorrect,
        'at': FieldValue.serverTimestamp(),
      };
      answers['$index'] = existingForIndex;

      final scores = Map<String, dynamic>.from((data['scores'] as Map?) ?? {});
      scores.putIfAbsent(hostId, () => 0);
      if (guestId.isNotEmpty) scores.putIfAbsent(guestId, () => 0);

      if (!alreadyAnswered && isCorrect) {
        final cur = (scores[userId] ?? 0) as int;
        scores[userId] = cur + 1;
      }

      final bothAnswered = hostId.isNotEmpty &&
          guestId.isNotEmpty &&
          existingForIndex.containsKey(hostId) &&
          existingForIndex.containsKey(guestId);

      final updates = <String, dynamic>{
        'answers': answers,
        'scores': scores,
      };

      if (bothAnswered) {
        locked['$index'] = true;
        updates['locked'] = locked;

        // ✅ AUTO-ADVANCE only if this is the current question
        if (index == currentIndex) {
          final next = currentIndex + 1;
          if (next >= questions.length) {
            updates['status'] = 'finished';
          } else {
            updates['currentIndex'] = next;
            updates['questionStartedAt'] = FieldValue.serverTimestamp();
          }
        }
      }

      tx.update(ref, updates);
    });
  }

  /// Called when timer hits 0 (from UI)
  /// Locks this index and auto-advances (no score changes).
  Future<void> forceLockIfTimeUp({
    required String rawCode,
    required int index,
  }) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      if ((data['status'] ?? '') != 'started') return;

      final locked = Map<String, dynamic>.from((data['locked'] as Map?) ?? {});
      if (locked['$index'] == true) return;

      locked['$index'] = true;

      final questions = (data['questions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      final currentIndex = (data['currentIndex'] ?? 0) as int;

      final updates = <String, dynamic>{
        'locked': locked,
      };

      if (index == currentIndex) {
        final next = currentIndex + 1;
        if (next >= questions.length) {
          updates['status'] = 'finished';
        } else {
          updates['currentIndex'] = next;
          updates['questionStartedAt'] = FieldValue.serverTimestamp();
        }
      }

      tx.update(ref, updates);
    });
  }

  /// Manual advance (optional fallback)
  Future<void> advanceQuestion(String rawCode) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Lobby not found.');

      final data = snap.data() ?? {};
      final status = (data['status'] ?? 'waiting') as String;
      final questions = (data['questions'] as List? ?? []);
      final idx = (data['currentIndex'] ?? 0) as int;

      if (status != 'started') return;

      final next = idx + 1;
      if (next >= questions.length) {
        tx.update(ref, {'status': 'finished'});
      } else {
        tx.update(ref, {
          'currentIndex': next,
          'questionStartedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
  ///comments
  Stream<BattleLobby?> watchLobby(String rawCode) {
    final code = normalizeCode(rawCode);
    return _ref(code).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BattleLobby.fromDoc(doc);
    });
  }
}