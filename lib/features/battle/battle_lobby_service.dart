import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'battle_lobby_model.dart';

class BattleLobbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'battle_lobbies';

  DocumentReference<Map<String, dynamic>> _ref(String code) =>
      _db.collection(_collection).doc(code);

  /// Normalize any user-entered lobby code
  String normalizeCode(String raw) {
    return raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .trim();
  }

  String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ------------------------------------------------------------
  // PHASE 1 — CREATE LOBBY
  // ------------------------------------------------------------
  Future<String> createLobby({
    required String userId,
    required List<String> questions,
  }) async {
    final q = List<String>.from(questions);
    if (q.length > 10) q.removeRange(10, q.length);

    for (int i = 0; i < 8; i++) {
      final code = _newCode();
      final ref = _ref(code);

      if ((await ref.get()).exists) continue;

      await ref.set({
        'hostId': userId,
        'guestId': null,
        'status': 'waiting',
        'questions': q,
        'currentIndex': 0,
        'scores': {userId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,

        // Phase 2 storage
        'answers': {},
        'locked': {},
        'options': {}, // populated when battle starts
      });

      return code;
    }

    throw Exception('Failed to create unique lobby code.');
  }

  // ------------------------------------------------------------
  // PHASE 1 — JOIN LOBBY
  // ------------------------------------------------------------
  Future<bool> joinLobby(String rawCode, String userId) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) return false;

    final ref = _ref(code);

    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;

      final data = snap.data()!;
      final status = data['status'] as String;
      final guestId = data['guestId'] as String?;
      final hostId = data['hostId'] as String;

      if (status == 'started' || status == 'finished') return false;
      if (guestId != null && guestId != userId) return false;

      final scores = Map<String, dynamic>.from(data['scores'] ?? {});
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

  // ------------------------------------------------------------
  // PHASE 2 — START BATTLE (FIXED OPTIONS ORDER)
  // ------------------------------------------------------------
  Future<void> startBattle(String rawCode) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Lobby not found');

      final data = snap.data()!;
      final status = data['status'] as String;
      final hostId = data['hostId'] as String;
      final guestId = data['guestId'] as String?;
      final questions = (data['questions'] as List).cast<String>();

      if (status != 'active') {
        throw Exception('Lobby not ready');
      }
      if (guestId == null || guestId.isEmpty) {
        throw Exception('Guest not joined');
      }

      // ✅ BUILD FIXED OPTIONS ONCE
      final Map<String, List<String>> options = {};

      for (int i = 0; i < questions.length; i++) {
        // TEMP simple version (Phase 3 improves this)
        final opts = List<String>.filled(4, questions[i]);
        opts.shuffle();
        options['$i'] = opts;
      }

      tx.update(ref, {
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
        'currentIndex': 0,
        'scores': {
          hostId: 0,
          guestId: 0,
        },
        'answers': {},
        'locked': {},
        'options': options, // 🔒 ORDER IS NOW LOCKED
      });
    });
  }

  // ------------------------------------------------------------
  // PHASE 2 — SUBMIT ANSWER
  // ------------------------------------------------------------
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
      if (!snap.exists) return;

      final data = snap.data()!;
      if (data['status'] != 'started') return;

      final answers = Map<String, dynamic>.from(data['answers'] ?? {});
      final locked = Map<String, dynamic>.from(data['locked'] ?? {});
      final scores = Map<String, dynamic>.from(data['scores'] ?? {});
      final hostId = data['hostId'] as String;
      final guestId = data['guestId'] as String;

      if (locked['$index'] == true) return;

      final perIndex =
          Map<String, dynamic>.from(answers['$index'] ?? {});
      if (perIndex.containsKey(userId)) return;

      perIndex[userId] = {
        'selected': selected,
        'correct': correct,
        'at': FieldValue.serverTimestamp(),
      };
      answers['$index'] = perIndex;

      if (correct) {
        scores[userId] = (scores[userId] ?? 0) + 1;
      }

      if (perIndex.containsKey(hostId) &&
          perIndex.containsKey(guestId)) {
        locked['$index'] = true;
      }

      tx.update(ref, {
        'answers': answers,
        'locked': locked,
        'scores': scores,
      });
    });
  }

  // ------------------------------------------------------------
  // PHASE 2 — ADVANCE QUESTION (HOST ONLY)
  // ------------------------------------------------------------
  Future<void> advanceQuestion(String rawCode) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      if (data['status'] != 'started') return;

      final idx = data['currentIndex'] as int;
      final total = (data['questions'] as List).length;

      if (idx + 1 >= total) {
        tx.update(ref, {'status': 'finished'});
      } else {
        tx.update(ref, {'currentIndex': idx + 1});
      }
    });
  }

  // ------------------------------------------------------------
  // REALTIME LISTENER
  // ------------------------------------------------------------
  Stream<BattleLobby?> watchLobby(String rawCode) {
    final code = normalizeCode(rawCode);
    return _ref(code).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BattleLobby.fromDoc(doc);
    });
  }
}