// lib/features/streak/streak_service_firebase.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore doc shape at users/{uid}
/// {
///   currentStreak: int,
///   highestStreak: int,
///   lastActiveDate: String (ISO),
///   rewardsClaimed: List<int>,
///   wordsViewed: int,
///   sharesCount: int,
///   badgesUnlocked: List<String>
/// }
class StreakFB {
  final int currentStreak;
  final int highestStreak;
  final DateTime? lastActiveDate;
  final List<int> rewardsClaimed;

  // Progress fields:
  final int wordsViewed;
  final int sharesCount;
  final List<String> badgesUnlocked;

  const StreakFB({
    required this.currentStreak,
    required this.highestStreak,
    required this.lastActiveDate,
    required this.rewardsClaimed,
    required this.wordsViewed,
    required this.sharesCount,
    required this.badgesUnlocked,
  });

  factory StreakFB.initial() => const StreakFB(
        currentStreak: 0,
        highestStreak: 0,
        lastActiveDate: null,
        rewardsClaimed: <int>[],
        wordsViewed: 0,
        sharesCount: 0,
        badgesUnlocked: <String>[],
      );

  factory StreakFB.fromMap(Map<String, dynamic>? m) {
    if (m == null) return StreakFB.initial();
    return StreakFB(
      currentStreak: (m['currentStreak'] ?? 0) as int,
      highestStreak: (m['highestStreak'] ?? 0) as int,
      lastActiveDate: (m['lastActiveDate'] is String)
          ? DateTime.tryParse(m['lastActiveDate'])
          : null,
      rewardsClaimed: (m['rewardsClaimed'] is List)
          ? List<int>.from(m['rewardsClaimed'] as List)
          : <int>[],
      wordsViewed: (m['wordsViewed'] ?? 0) as int,
      sharesCount: (m['sharesCount'] ?? 0) as int,
      badgesUnlocked: (m['badgesUnlocked'] is List)
          ? List<String>.from(m['badgesUnlocked'] as List)
          : <String>[],
    );
  }

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'highestStreak': highestStreak,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'rewardsClaimed': rewardsClaimed,
        'wordsViewed': wordsViewed,
        'sharesCount': sharesCount,
        'badgesUnlocked': badgesUnlocked,
      };

  StreakFB copyWith({
    int? currentStreak,
    int? highestStreak,
    DateTime? lastActiveDate,
    List<int>? rewardsClaimed,
    int? wordsViewed,
    int? sharesCount,
    List<String>? badgesUnlocked,
  }) {
    return StreakFB(
      currentStreak: currentStreak ?? this.currentStreak,
      highestStreak: highestStreak ?? this.highestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      rewardsClaimed: rewardsClaimed ?? this.rewardsClaimed,
      wordsViewed: wordsViewed ?? this.wordsViewed,
      sharesCount: sharesCount ?? this.sharesCount,
      badgesUnlocked: badgesUnlocked ?? this.badgesUnlocked,
    );
  }
}

class StreakServiceFirebase {
  final FirebaseFirestore _db;
  final String uid;

  StreakServiceFirebase({String? uid})
      : _db = FirebaseFirestore.instance,
        uid = uid ?? FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _doc() =>
      _db.collection('users').doc(uid);

  DateTime _justDate(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---------- Badge IDs ----------
  // Streak
  static const String bStreak3 = 'streak_3';
  static const String bStreak7 = 'streak_7';
  static const String bStreak14 = 'streak_14';
  static const String bStreak30 = 'streak_30';
  static const String bStreak60 = 'streak_60';
  static const String bStreak100 = 'streak_100';
  static const String bStreak365 = 'streak_365';

  // Usage
  static const String bFirstWord = 'first_word';
  static const String bWords10 = 'words_10';
  static const String bWords50 = 'words_50';
  static const String bWords100 = 'words_100';

  // Behavior / Misc
  static const String bFirstClaim = 'first_claim';
  static const String bShared1 = 'shared_1';
  static const String bNightOwl = 'night_owl';
  static const String bEarlyBird = 'early_bird';
  static const String bWeekendWarrior = 'weekend_warrior';
  static const String bComebackKid = 'comeback_kid';

  /// Call at app open. Handles streak math and auto-unlocks time-based badges.
  Future<StreakFB> touchToday() async {
    return _db.runTransaction((tx) async {
      final ref = _doc();
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());

      final now = DateTime.now();
      final today = _justDate(now);
      final last = cur.lastActiveDate == null ? null : _justDate(cur.lastActiveDate!);

      int streak = cur.currentStreak;
      int best = cur.highestStreak;

      if (last == null) {
        streak = 1;
      } else {
        final diff = today.difference(last).inDays;
        if (diff == 0) {
          // already counted today
        } else if (diff == 1) {
          streak += 1;
        } else if (diff > 1) {
          // missed days → reset + comeback badge
          streak = 1;
          _addBadgeInTx(tx, ref, bComebackKid);
        }
      }
      if (streak > best) best = streak;

      final next = cur.copyWith(
        currentStreak: streak,
        highestStreak: best,
        lastActiveDate: today,
      );
      if (snap.exists) {
        tx.update(ref, next.toMap());
      } else {
        tx.set(ref, next.toMap());
      }

      // Auto-unlock streak badges
      _checkAndUnlockStreakBadges(tx, ref, next);

      // Time-of-day badges
      final hour = now.hour;
      if (hour < 7) {
        _addBadgeInTx(tx, ref, bEarlyBird);
      } else if (hour >= 23) {
        _addBadgeInTx(tx, ref, bNightOwl);
      }

      // Weekend Warrior helper markers (simple MVP):
      // add 'wknd_sat' / 'wknd_sun', then collapse into main badge.
      if (today.weekday == DateTime.saturday) {
        _addBadgeInTx(tx, ref, 'wknd_sat');
      } else if (today.weekday == DateTime.sunday) {
        _addBadgeInTx(tx, ref, 'wknd_sun');
      }
      _tryUnlockWeekendWarrior(tx, ref);

      return next;
    });
  }

  Future<StreakFB> getCurrent() async {
    final snap = await _doc().get();
    return StreakFB.fromMap(snap.data());
  }

  /// Milestone claim (3/7/14/30/60/100/365). Also unlocks first-claim badge.
  Future<void> claim(int day) async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      if (!cur.rewardsClaimed.contains(day)) {
        final updated = List<int>.from(cur.rewardsClaimed)..add(day);
        if (snap.exists) {
          tx.update(ref, {'rewardsClaimed': updated});
        } else {
          tx.set(ref, cur.copyWith(rewardsClaimed: updated).toMap());
        }
        _addBadgeInTx(tx, ref, bFirstClaim);
      }
    });
  }

  /// Track a slang view; unlock usage badges on thresholds.
  Future<void> trackWordViewed() async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      final count = cur.wordsViewed + 1;

      if (snap.exists) {
        tx.update(ref, {'wordsViewed': count});
      } else {
        tx.set(ref, cur.copyWith(wordsViewed: count).toMap());
      }

      if (count >= 1) _addBadgeInTx(tx, ref, bFirstWord);
      if (count >= 10) _addBadgeInTx(tx, ref, bWords10);
      if (count >= 50) _addBadgeInTx(tx, ref, bWords50);
      if (count >= 100) _addBadgeInTx(tx, ref, bWords100);
    });
  }

  /// Track a share action; unlock 'shared_1'.
  Future<void> trackShared() async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      final count = cur.sharesCount + 1;

      if (snap.exists) {
        tx.update(ref, {'sharesCount': count});
      } else {
        tx.set(ref, cur.copyWith(sharesCount: count).toMap());
      }

      if (count >= 1) _addBadgeInTx(tx, ref, bShared1);
    });
  }

  /// Realtime updates so your UI stays in sync.
  Stream<StreakFB> watch() =>
      _doc().snapshots().map((s) => StreakFB.fromMap(s.data()));

  // ---------- Debug helpers (optional) ----------
  Future<void> debugPrepareForDay(int targetDay) async {
    if (targetDay < 1) return;
    final ref = _doc();
    final now = DateTime.now();
    final today = _justDate(now);
    final yesterday = today.subtract(const Duration(days: 1));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      final prepared = cur.copyWith(
        currentStreak: targetDay - 1,
        highestStreak:
            (targetDay - 1) > cur.highestStreak ? (targetDay - 1) : cur.highestStreak,
        lastActiveDate: yesterday,
      );
      if (snap.exists) {
        tx.update(ref, prepared.toMap());
      } else {
        tx.set(ref, prepared.toMap());
      }
    });
  }

  Future<void> debugUnclaim(int day) async {
    final ref = _doc();
    await ref.update({'rewardsClaimed': FieldValue.arrayRemove([day])});
  }

  // ---------- Private helpers ----------
  void _addBadgeInTx(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    String id,
  ) {
    tx.update(ref, {
      'badgesUnlocked': FieldValue.arrayUnion([id]),
    });
  }

  void _tryUnlockWeekendWarrior(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    // Remove markers if present, then add the main badge (idempotent).
    tx.update(ref, {
      'badgesUnlocked': FieldValue.arrayRemove(['wknd_sat', 'wknd_sun']),
    });
    tx.update(ref, {
      'badgesUnlocked': FieldValue.arrayUnion([bWeekendWarrior]),
    });
  }

  void _checkAndUnlockStreakBadges(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    StreakFB s,
  ) {
    final thresholds = <int, String>{
      3: bStreak3,
      7: bStreak7,
      14: bStreak14,
      30: bStreak30,
      60: bStreak60,
      100: bStreak100,
      365: bStreak365,
    };
    for (final e in thresholds.entries) {
      if (s.currentStreak >= e.key) {
        tx.update(ref, {'badgesUnlocked': FieldValue.arrayUnion([e.value])});
      }
    }
  }
}