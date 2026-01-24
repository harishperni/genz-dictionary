import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'battle_lobby_model.dart';

class BattleLobbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'battle_lobbies';

  // ✅ reveal delay before moving to next question
  static const int _advanceDelayMs = 2500;

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
  /// displayName is optional so your existing calls won't break.
  Future<String> createLobby({
    required String userId,
    required List<String> questions,
    String? displayName,
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
        'locked': {}, // index -> true

        // frozen options for the whole game
        'options': {}, // index -> [4 options]

        // timer (✅ 15s default)
        'timerSeconds': 15,
        'questionStartedAt': null,

        // sync start
        'battleStartsAt': null,

        // reveal/advance
        'advanceAt': null,
        'advanceDelayMs': _advanceDelayMs,

        // winner names (fallback)
        'playerNames': {userId: (displayName?.trim().isNotEmpty == true) ? displayName!.trim() : 'Host'},
      });

      return code;
    }

    throw Exception('Failed to create unique lobby code.');
  }

  /// Guest joins lobby (waiting/active) -> sets guestId + status=active
  /// displayName is optional so your existing calls won't break.
  Future<bool> joinLobby(String rawCode, String userId, {String? displayName}) async {
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

      final playerNames = Map<String, dynamic>.from((data['playerNames'] as Map?) ?? {});
      playerNames.putIfAbsent(hostId, () => 'Host');
      playerNames[userId] = (displayName?.trim().isNotEmpty == true) ? displayName!.trim() : 'Guest';

      tx.update(ref, {
        'guestId': userId,
        'status': 'active',
        'scores': scores,
        'playerNames': playerNames,
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
    int timerSeconds = 15, // ✅ 15s
    int startDelayMs = 900, // buffer so both devices navigate + start together
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

      // Build & freeze options for ALL questions once
      final options = <String, dynamic>{};

      // pool of meanings for wrong answers
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

      // ensure playerNames exists
      final playerNames = Map<String, dynamic>.from((data['playerNames'] as Map?) ?? {});
      playerNames.putIfAbsent(hostId, () => 'Host');
      playerNames.putIfAbsent(guestId, () => 'Guest');

      tx.update(ref, {
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
        'currentIndex': 0,
        'scores': scores,

        'answers': {},
        'locked': {},

        'options': options,

        'timerSeconds': timerSeconds,

        // shared sync fields
        'battleStartsAt': Timestamp.fromDate(battleStartsAt),
        'questionStartedAt': Timestamp.fromDate(battleStartsAt),

        // reveal/advance
        'advanceAt': null,
        'advanceDelayMs': _advanceDelayMs,

        'playerNames': playerNames,
      });
    });
  }

  /// Submit answer:
  /// - saves answers[index][uid]
  /// - increments score once if correct
  /// - locks when both answered
  /// - ✅ DOES NOT auto-advance immediately
  /// - ✅ sets advanceAt so both can see red/green for ~2.5s
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

        // ✅ start reveal window now (server time)
        updates['advanceAt'] = FieldValue.serverTimestamp();
        updates['advanceDelayMs'] = _advanceDelayMs;
      }

      tx.update(ref, updates);
    });
  }

  /// Called when timer hits 0 (from UI)
  /// Locks this index and schedules advance after reveal window.
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

      tx.update(ref, {
        'locked': locked,
        'advanceAt': FieldValue.serverTimestamp(),
        'advanceDelayMs': _advanceDelayMs,
      });
    });
  }

  /// ✅ Advance when reveal window is complete.
  /// Safe to call from either phone many times.
  Future<void> advanceIfDue({required String rawCode}) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      if ((data['status'] ?? '') != 'started') return;

      final advanceAtTs = data['advanceAt'] as Timestamp?;
      if (advanceAtTs == null) return;

      final delayMs = (data['advanceDelayMs'] ?? _advanceDelayMs) as int;

      final dueAt = advanceAtTs.toDate().add(Duration(milliseconds: delayMs));
      final now = DateTime.now(); // device time; ok because dueAt is server-based
      if (now.isBefore(dueAt)) return;

      final questions = (data['questions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();

      final idx = (data['currentIndex'] ?? 0) as int;
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