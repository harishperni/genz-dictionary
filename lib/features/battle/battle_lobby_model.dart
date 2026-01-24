import 'package:cloud_firestore/cloud_firestore.dart';

class BattleLobby {
  final String id;

  final String hostId;
  final String? guestId;

  /// waiting | active | started | finished
  final String status;

  final List<String> questions;
  final int currentIndex;

  /// scores[uid] = int
  final Map<String, int> scores;

  /// answers["0"][uid] = { selected, correct, at }
  final Map<String, dynamic> answers;

  /// locked["0"] = true
  final Map<String, dynamic> locked;

  /// options["0"] = [ "correct", "wrong1", "wrong2", "wrong3" ]
  final Map<String, List<String>> options;

  /// timerSeconds = 15
  final int timerSeconds;

  /// Timestamp when current question timer started (server time)
  final DateTime? questionStartedAt;

  /// Timestamp when battle should start (server time) — used for sync
  final DateTime? battleStartsAt;

  /// When a question becomes locked, we set advanceAt = serverTimestamp().
  /// Client waits (advanceDelayMs) then advances.
  final DateTime? advanceAt;
  final int advanceDelayMs;

  /// uid -> displayName (optional). Falls back to Host/Guest if missing.
  final Map<String, String> playerNames;

  final DateTime? createdAt;
  final DateTime? startedAt;

  BattleLobby({
    required this.id,
    required this.hostId,
    required this.guestId,
    required this.status,
    required this.questions,
    required this.currentIndex,
    required this.scores,
    required this.answers,
    required this.locked,
    required this.options,
    required this.timerSeconds,
    required this.questionStartedAt,
    required this.battleStartsAt,
    required this.advanceAt,
    required this.advanceDelayMs,
    required this.playerNames,
    required this.createdAt,
    required this.startedAt,
  });

  /// Backwards-friendly getter (some pages use durationSec)
  int get durationSec => timerSeconds;

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static Map<String, int> _parseScores(dynamic raw) {
    final sRaw = (raw as Map?) ?? const {};
    final out = <String, int>{};
    sRaw.forEach((k, v) {
      out[k.toString()] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
    });
    return out;
  }

  static Map<String, dynamic> _parseStringKeyedMap(dynamic raw) {
    final m = (raw as Map?) ?? const {};
    final out = <String, dynamic>{};
    m.forEach((k, v) => out[k.toString()] = v);
    return out;
  }

  static Map<String, List<String>> _parseOptions(dynamic raw) {
    final m = (raw as Map?) ?? const {};
    final out = <String, List<String>>{};
    m.forEach((k, v) {
      final key = k.toString();
      if (v is List) {
        out[key] = v.map((e) => e.toString()).toList();
      } else {
        out[key] = const <String>[];
      }
    });
    return out;
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    final m = (raw as Map?) ?? const {};
    final out = <String, String>{};
    m.forEach((k, v) => out[k.toString()] = v?.toString() ?? '');
    return out;
  }

  factory BattleLobby.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final qRaw = (data['questions'] as List?) ?? const [];
    final questions = qRaw.map((e) => e.toString()).toList();

    return BattleLobby(
      id: doc.id,
      hostId: (data['hostId'] ?? '') as String,
      guestId: data['guestId'] as String?,
      status: (data['status'] ?? 'waiting') as String,
      questions: questions,
      currentIndex: (data['currentIndex'] ?? 0) as int,

      scores: _parseScores(data['scores']),
      answers: _parseStringKeyedMap(data['answers']),
      locked: _parseStringKeyedMap(data['locked']),
      options: _parseOptions(data['options']),

      timerSeconds: (data['timerSeconds'] ?? 15) as int,
      questionStartedAt: _ts(data['questionStartedAt']),
      battleStartsAt: _ts(data['battleStartsAt']),

      advanceAt: _ts(data['advanceAt']),
      advanceDelayMs: (data['advanceDelayMs'] ?? 2500) as int,

      playerNames: _parseStringMap(data['playerNames']),

      createdAt: _ts(data['createdAt']),
      startedAt: _ts(data['startedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'guestId': guestId,
      'status': status,
      'questions': questions,
      'currentIndex': currentIndex,
      'scores': scores,
      'answers': answers,
      'locked': locked,
      'options': options,
      'timerSeconds': timerSeconds,
      'questionStartedAt': questionStartedAt,
      'battleStartsAt': battleStartsAt,
      'advanceAt': advanceAt,
      'advanceDelayMs': advanceDelayMs,
      'playerNames': playerNames,
      'createdAt': createdAt,
      'startedAt': startedAt,
    };
  }
}