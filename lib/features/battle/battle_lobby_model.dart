import 'package:cloud_firestore/cloud_firestore.dart';

class BattleLobby {
  final String id;
  final String hostId;
  final String? guestId;
  final List<String> questions;
  final String status;
  final DateTime createdAt;
  final Map<String, int> scores;

  BattleLobby({
    required this.id,
    required this.hostId,
    this.guestId,
    required this.questions,
    required this.status,
    required this.createdAt,
    this.scores = const {},
  });

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'guestId': guestId,
      'questions': questions,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'scores': scores,
    };
  }

  // Create object from Firestore map
  factory BattleLobby.fromMap(Map<String, dynamic> data, String id) {
    return BattleLobby(
      id: id,
      hostId: data['hostId'] ?? '',
      guestId: data['guestId'],
      questions: List<String>.from(data['questions'] ?? []),
      status: data['status'] ?? 'waiting',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      scores: Map<String, int>.from(data['scores'] ?? {}),
    );
  }

  // Optional: helper to rebuild with updates
  BattleLobby copyWith({
    String? id,
    String? hostId,
    String? guestId,
    List<String>? questions,
    String? status,
    DateTime? createdAt,
    Map<String, int>? scores,
  }) {
    return BattleLobby(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      guestId: guestId ?? this.guestId,
      questions: questions ?? this.questions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      scores: scores ?? this.scores,
    );
  }

  // Convenience Firestore doc converter
  static BattleLobby fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BattleLobby.fromMap(data, doc.id);
  }
}