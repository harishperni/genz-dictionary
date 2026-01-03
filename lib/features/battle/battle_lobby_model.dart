// lib/features/battle/battle_lobby_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BattleLobby {
  final String id;
  final String hostId;
  final String? guestId;
  final String status; // waiting | active | started | finished
  final List<String> questions;
  final int currentIndex;

  // ✅ Freeze options per question index: "0": ["A","B","C","D"]
  final Map<String, List<String>> options;

  // ✅ Answers map: index -> uid -> {selected, correct, at}
  final Map<String, dynamic> answers;

  // ✅ Locked map: index -> true
  final Map<String, dynamic> locked;

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

    final qRaw = (data['questions'] as List?) ?? const [];
    final questions = qRaw.map((e) => e.toString()).toList();

    // options
    final oRaw = (data['options'] as Map?) ?? const {};
    final options = <String, List<String>>{};
    oRaw.forEach((k, v) {
      options[k.toString()] = (v as List).map((e) => e.toString()).toList();
    });

    // answers/locked
    final answers = Map<String, dynamic>.from((data['answers'] as Map?) ?? {});
    final locked = Map<String, dynamic>.from((data['locked'] as Map?) ?? {});

    // scores
    final sRaw = (data['scores'] as Map?) ?? const {};
    final scores = <String, int>{};
    sRaw.forEach((k, v) {
      scores[k.toString()] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
    });

    DateTime? _ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

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
      createdAt: _ts(data['createdAt']),
      startedAt: _ts(data['startedAt']),
    );
  }
}