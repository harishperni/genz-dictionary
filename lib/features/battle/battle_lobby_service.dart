import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'battle_lobby_model.dart';

class BattleLobbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'battle_lobbies';

  DocumentReference<Map<String, dynamic>> _ref(String code) =>
      _db.collection(_collection).doc(code);

  String normalizeCode(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
  }

  String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// serverNow - localNow
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

        'answers': {},
        'locked': {},
        'options': {},

        // ✅ default 15 seconds
        'timerSeconds': 15,
        'questionStartedAt': null,
        'battleStartsAt': null,

        // ✅ NEW
        'advanceAt': null,
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

  Future<void> startBattle({
    required String rawCode,
    required Map<String, String> termToMeaning,
    int timerSeconds = 15,
    int startDelayMs = 900,
  }) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) throw Exception('Invalid lobby code.');

    final ref = _ref(code);

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

      if (status != 'active') throw Exception('Lobby not ready (need guest).');
      if (guestId == null || guestId.isEmpty) throw Exception('No guest joined.');
      if (questions.isEmpty) throw Exception('No questions in lobby.');

      final scores = <String, dynamic>{hostId: 0, guestId: 0};

      final options = <String, dynamic>{};

      final allMeanings = termToMeaning.values
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();

      for (int i = 0; i < questions.length; i++) {
        final term = questions[i];
        final correct = (termToMeaning[term] ?? '').trim();

        final wrongPool = allMeanings.where((m) => m != correct).toList()..shuffle();

        final wrongs = <String>[];
        for (final w in wrongPool) {
          if (wrongs.length >= 3) break;
          if (!wrongs.contains(w)) wrongs.add(w);
        }
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

        'battleStartsAt': Timestamp.fromDate(battleStartsAt),
        'questionStartedAt': Timestamp.fromDate(battleStartsAt),

        // ✅ NEW
        'advanceAt': null,
      });
    });
  }

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
      if ((data['status'] ?? 'waiting') != 'started') return;

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

      // ✅ Instead of immediate advance: lock + set advanceAt (2 sec reveal)
      if (bothAnswered && index == currentIndex) {
        locked['$index'] = true;
        updates['locked'] = locked;

        // only set if not already set
        final existingAdvanceAt = data['advanceAt'];
        if (existingAdvanceAt == null) {
          updates['advanceAt'] = FieldValue.serverTimestamp();
          // NOTE: we’ll interpret this as "now", and host will add delay using offset in UI
          // (we avoid server-side math limitations)
        }
      }

      tx.update(ref, updates);
    });
  }

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

      final currentIndex = (data['currentIndex'] ?? 0) as int;
      if (index != currentIndex) return;

      locked['$index'] = true;

      final updates = <String, dynamic>{
        'locked': locked,
      };

      if (data['advanceAt'] == null) {
        updates['advanceAt'] = FieldValue.serverTimestamp();
      }

      tx.update(ref, updates);
    });
  }

  /// ✅ Host-only advance after reveal delay (2–3s)
  Future<void> advanceIfReady({
    required String rawCode,
    required String hostUserId,
    required Duration serverOffset,
    int revealDelayMs = 2200,
  }) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      if ((data['status'] ?? '') != 'started') return;

      final hostId = (data['hostId'] ?? '') as String;
      if (hostId != hostUserId) return;

      final questions = (data['questions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      final idx = (data['currentIndex'] ?? 0) as int;

      final locked = Map<String, dynamic>.from((data['locked'] as Map?) ?? {});
      if (locked['$idx'] != true) return;

      final advRaw = data['advanceAt'];
      if (advRaw is! Timestamp) return;

      final advAtServer = advRaw.toDate();
      final serverNow = DateTime.now().add(serverOffset);

      // wait revealDelayMs from advanceAt
      if (serverNow.isBefore(advAtServer.add(Duration(milliseconds: revealDelayMs)))) {
        return;
      }

      final next = idx + 1;
      if (next >= questions.length) {
        tx.update(ref, {
          'status': 'finished',
          'advanceAt': null,
        });
      } else {
        tx.update(ref, {
          'currentIndex': next,
          'questionStartedAt': FieldValue.serverTimestamp(),
          'advanceAt': null,
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