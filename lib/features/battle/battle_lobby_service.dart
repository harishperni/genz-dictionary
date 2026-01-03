// lib/features/battle/battle_lobby_service.dart
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

        // ✅ Phase 2 data
        'options': {}, // "0": ["A","B","C","D"]
        'answers': {}, // "0": { uid: {selected, correct, at} }
        'locked': {},  // "0": true
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

      // safe join
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

  Future<void> startBattle(String rawCode) async {
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
      final questions = (data['questions'] as List? ?? const []);

      if (status != 'active') throw Exception('Lobby not ready. Waiting for guest.');
      if (guestId == null || guestId.isEmpty) throw Exception('No guest joined yet.');
      if (questions.isEmpty) throw Exception('No questions.');

      tx.update(ref, {
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
        'currentIndex': 0,
        'scores': {hostId: 0, guestId: 0},
        'answers': {},
        'locked': {},
        // options stays (generated as needed)
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
      final questions = (data['questions'] as List? ?? []);
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

  /// ✅ Freeze options once (host should call this when missing)
  Future<void> setOptionsIfMissing({
    required String rawCode,
    required int index,
    required List<String> options,
  }) async {
    final code = normalizeCode(rawCode);
    final ref = _ref(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final map = Map<String, dynamic>.from((data['options'] as Map?) ?? {});
      if (map.containsKey('$index')) return; // already frozen
      map['$index'] = options;
      tx.update(ref, {'options': map});
    });
  }

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
      if (locked['$index'] == true) return;

      final existingForIndex =
          Map<String, dynamic>.from((answers['$index'] as Map?) ?? {});
      final alreadyAnswered = existingForIndex.containsKey(userId);

      existingForIndex[userId] = {
        'selected': selected,
        'correct': correct,
        'at': FieldValue.serverTimestamp(),
      };
      answers['$index'] = existingForIndex;

      final scores = Map<String, dynamic>.from((data['scores'] as Map?) ?? {});
      scores.putIfAbsent(hostId, () => 0);
      if (guestId.isNotEmpty) scores.putIfAbsent(guestId, () => 0);

      if (!alreadyAnswered && correct == true) {
        scores[userId] = ((scores[userId] ?? 0) as int) + 1;
      }

      final bothAnswered = hostId.isNotEmpty &&
          guestId.isNotEmpty &&
          existingForIndex.containsKey(hostId) &&
          existingForIndex.containsKey(guestId);

      if (bothAnswered) locked['$index'] = true;

      tx.update(ref, {
        'answers': answers,
        'locked': locked,
        'scores': scores,
      });
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