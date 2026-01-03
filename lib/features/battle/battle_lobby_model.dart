import 'package:cloud_firestore/cloud_firestore.dart';

class BattleLobby {
  final String id;
  final String hostId;
  final String? guestId;
  final String status; // waiting | active | started | finished

  final List<String> questions;
  final int currentIndex;

  /// ✅ Phase 2
  /// options[index] = ordered list of options (stable for both players)
  final Map<String, List<String>> options;

  /// answers[index][uid] = { selected, correct, at }
  final Map<String, dynamic> answers;

  /// locked[index] = true
  final Map<String, bool> locked;

  final Map<String, int> scores;

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
    required this.createdAt,
    required this.startedAt,
  });

  factory BattleLobby.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    Map<String, List<String>> _parseOptions() {
      final raw = Map<String, dynamic>.from(data['options'] ?? {});
      return raw.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    }

    Map<String, int> _parseScores() {
      final raw = Map<String, dynamic>.from(data['scores'] ?? {});
      return raw.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
    }

    DateTime? _ts(dynamic v) =>
        v is Timestamp ? v.toDate() : null;

    return BattleLobby(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      guestId: data['guestId'],
      status: data['status'] ?? 'waiting',
      questions: List<String>.from(data['questions'] ?? []),
      currentIndex: (data['currentIndex'] ?? 0) as int,
      options: _parseOptions(),
      answers: Map<String, dynamic>.from(data['answers'] ?? {}),
      locked: Map<String, bool>.from(data['locked'] ?? {}),
      scores: _parseScores(),
      createdAt: _ts(data['createdAt']),
      startedAt: _ts(data['startedAt']),
    );
  }
}