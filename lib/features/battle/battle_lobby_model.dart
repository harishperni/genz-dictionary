import 'package:cloud_firestore/cloud_firestore.dart';

class BattleLobby {
  final String id;
  final String hostId;
  final String? guestId;

  /// waiting | active | started | finished
  final String status;

  final List<String> questions;
  final int currentIndex;

  /// Phase 2/3: precomputed options for each question index
  /// Firestore shape:
  /// options: { "0": ["A","B","C","D"], "1": [...] }
  final Map<String, List<String>> options;

  /// Phase 2: answers map
  /// answers: { "0": { "uid1": {selected, correct, at}, "uid2": {...} } }
  final Map<String, dynamic> answers;

  /// Phase 2: locked map
  /// locked: { "0": true, "1": true }
  final Map<String, bool> locked;

  /// scores: { uid: int }
  final Map<String, int> scores;

  /// Phase 3: timer settings (optional)
  /// durationSec: 10
  final int durationSec;

  /// Optional timestamps
  final DateTime? createdAt;
  final DateTime? startedAt;

  BattleLobby({
    required this.id,
    required this.hostId,
    required this.guestId,
    required this.status,
    required this.questions,
    required this.currentIndex,
    required this.options,
    required this.answers,
    required this.locked,
    required this.scores,
    required this.durationSec,
    required this.createdAt,
    required this.startedAt,
  });

  factory BattleLobby.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? _ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    // questions
    final qRaw = (data['questions'] as List?) ?? const [];
    final questions = qRaw.map((e) => e.toString()).toList();

    // options
    final oRaw = (data['options'] as Map?) ?? const {};
    final options = <String, List<String>>{};
    oRaw.forEach((k, v) {
      if (v is List) {
        options[k.toString()] = v.map((e) => e.toString()).toList();
      }
    });

    // answers (map)
    final aRaw = (data['answers'] as Map?) ?? const {};
    final answers = Map<String, dynamic>.from(aRaw);

    // locked (map)
    final lRaw = (data['locked'] as Map?) ?? const {};
    final locked = <String, bool>{};
    lRaw.forEach((k, v) {
      locked[k.toString()] = v == true;
    });

    // scores
    final sRaw = (data['scores'] as Map?) ?? const {};
    final scores = <String, int>{};
    sRaw.forEach((k, v) {
      scores[k.toString()] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
    });

    return BattleLobby(
      id: doc.id,
      hostId: (data['hostId'] ?? '') as String,
      guestId: data['guestId'] as String?,
      status: (data['status'] ?? 'waiting') as String,
      questions: questions,
      currentIndex: (data['currentIndex'] ?? 0) as int,
      options: options,
      answers: answers,
      locked: locked,
      scores: scores,
      durationSec: (data['durationSec'] ?? 10) as int,
      createdAt: _ts(data['createdAt']),
      startedAt: _ts(data['startedAt']),
    );
  }
}