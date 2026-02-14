import 'package:cloud_firestore/cloud_firestore.dart';

class BattleHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Write battle result ONCE, and update stats for both players.
  /// Uses a lobby-level guard flag so we never double-write.
  Future<void> recordBattleIfNeeded({
    required String lobbyCode,
  }) async {
    final lobbyRef = _db.collection('battle_lobbies').doc(lobbyCode);

    await _db.runTransaction((tx) async {
      final lobbySnap = await tx.get(lobbyRef);
      if (!lobbySnap.exists) return;

      final data = lobbySnap.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '') as String;
      if (status != 'finished') return;

      // ✅ Guard: only write once
      final alreadyRecorded = (data['resultRecorded'] == true);
      if (alreadyRecorded) return;

      final hostId = (data['hostId'] ?? '') as String;
      final guestId = (data['guestId'] ?? '') as String;
      if (hostId.isEmpty || guestId.isEmpty) return;

      final scoresRaw = (data['scores'] as Map?) ?? {};
      final hostScore = (scoresRaw[hostId] ?? 0) as int;
      final guestScore = (scoresRaw[guestId] ?? 0) as int;

      final questions = (data['questions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      final questionCount = questions.length;

      // optional timing
      final startedAtTs = data['startedAt'];
      final createdAtTs = data['createdAt'];
      DateTime? startedAt;
      DateTime? createdAt;
      if (startedAtTs is Timestamp) startedAt = startedAtTs.toDate();
      if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

      // battle ended now (server)
      final endedAt = FieldValue.serverTimestamp();

      String outcomeFor(String uid) {
        final my = uid == hostId ? hostScore : guestScore;
        final opp = uid == hostId ? guestScore : hostScore;
        if (my > opp) return 'win';
        if (my < opp) return 'loss';
        return 'tie';
      }

      String opponentFor(String uid) => uid == hostId ? guestId : hostId;

      int myScoreFor(String uid) => uid == hostId ? hostScore : guestScore;
      int oppScoreFor(String uid) => uid == hostId ? guestScore : hostScore;

      final battleId = lobbyCode; // simple stable id
      final base = <String, dynamic>{
        'battleId': battleId,
        'lobbyCode': lobbyCode,
        'hostId': hostId,
        'guestId': guestId,
        'hostScore': hostScore,
        'guestScore': guestScore,
        'questionCount': questionCount,
        'createdAt': createdAt,
        'startedAt': startedAt,
        'endedAt': endedAt,
      };

      // Write per-user history docs
      for (final uid in [hostId, guestId]) {
        final histRef = _db
            .collection('users')
            .doc(uid)
            .collection('battle_history')
            .doc(battleId);

        tx.set(histRef, {
          ...base,
          'uid': uid,
          'opponentId': opponentFor(uid),
          'myScore': myScoreFor(uid),
          'opponentScore': oppScoreFor(uid),
          'outcome': outcomeFor(uid), // win|loss|tie
          'recordedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update aggregated stats
        final statsRef =
            _db.collection('users').doc(uid).collection('battle_stats').doc('main');

        final outcome = outcomeFor(uid);
        tx.set(statsRef, {
          'gamesPlayed': FieldValue.increment(1),
          'wins': FieldValue.increment(outcome == 'win' ? 1 : 0),
          'losses': FieldValue.increment(outcome == 'loss' ? 1 : 0),
          'ties': FieldValue.increment(outcome == 'tie' ? 1 : 0),
          'totalCorrect': FieldValue.increment(myScoreFor(uid)),
          'totalQuestions': FieldValue.increment(questionCount),
          'lastBattleAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Mark lobby as recorded to prevent duplicates
      tx.update(lobbyRef, {
        'resultRecorded': true,
        'resultRecordedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Stream last N battles for a user
  Stream<List<Map<String, dynamic>>> watchHistory(String uid, {int limit = 30}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('battle_history')
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map((d) => d.data()).toList());
  }

  /// Stream stats doc
  Stream<Map<String, dynamic>?> watchStats(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('battle_stats')
        .doc('main')
        .snapshots()
        .map((d) => d.data());
  }
}