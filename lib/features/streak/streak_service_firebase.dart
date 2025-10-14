import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore doc structure:
/// users/{uid} → {
///   currentStreak: int,
///   highestStreak: int,
///   lastActiveDate: String,
///   rewardsClaimed: [int],
///   wordsViewed: int,
///   wordsToday: int,
///   lastWordXPDate: String,
///   sharesCount: int,
///   xp: int,
///   level: int,
///   badgesUnlocked: [String]
/// }

class StreakFB {
  final int currentStreak;
  final int highestStreak;
  final DateTime? lastActiveDate;
  final List<int> rewardsClaimed;

  final int wordsViewed;
  final int sharesCount;
  final int xp;
  final int level;
  final List<String> badgesUnlocked;

  const StreakFB({
    required this.currentStreak,
    required this.highestStreak,
    required this.lastActiveDate,
    required this.rewardsClaimed,
    required this.wordsViewed,
    required this.sharesCount,
    required this.xp,
    required this.level,
    required this.badgesUnlocked,
  });

  factory StreakFB.initial() => const StreakFB(
        currentStreak: 0,
        highestStreak: 0,
        lastActiveDate: null,
        rewardsClaimed: <int>[],
        wordsViewed: 0,
        sharesCount: 0,
        xp: 0,
        level: 1,
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
          ? List<int>.from(m['rewardsClaimed'])
          : <int>[],
      wordsViewed: (m['wordsViewed'] ?? 0) as int,
      sharesCount: (m['sharesCount'] ?? 0) as int,
      xp: (m['xp'] ?? 0) as int,
      level: (m['level'] ?? 1) as int,
      badgesUnlocked: (m['badgesUnlocked'] is List)
          ? List<String>.from(m['badgesUnlocked'])
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
        'xp': xp,
        'level': level,
        'badgesUnlocked': badgesUnlocked,
      };
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

  // ---------- BADGE CONSTANTS ----------

  // 🔥 Streak
  static const String bStreak3 = 'streak_3';
  static const String bStreak7 = 'streak_7';
  static const String bStreak14 = 'streak_14';
  static const String bStreak30 = 'streak_30';
  static const String bStreak60 = 'streak_60';
  static const String bStreak100 = 'streak_100';
  static const String bStreak365 = 'streak_365';

  // 📚 Usage
  static const String bFirstWord = 'first_word';
  static const String bWords10 = 'words_10';
  static const String bWords50 = 'words_50';
  static const String bWords100 = 'words_100';
  static const String bWords250 = 'words_250';
  static const String bWords500 = 'words_500';

  // 💬 Sharing & Community
  static const String bShared1 = 'shared_1';
  static const String bShared5 = 'shared_5';
  static const String bShared25 = 'shared_25';
  static const String bShared50 = 'shared_50';
  static const String bInvite1 = 'invite_1';
  static const String bInvite5 = 'invite_5';

  // ⏰ Behavior
  static const String bEarlyBird = 'early_bird';
  static const String bNightOwl = 'night_owl';
  static const String bWeekendWarrior = 'weekend_warrior';
  static const String bComebackKid = 'comeback_kid';

  // 💎 Milestones / Loyalty
  static const String bFirstClaim = 'first_claim';
  static const String bMonthUser = 'account_30d';
  static const String bYearUser = 'account_365d';
  static const String bFeedbackGiven = 'feedback_given';

  // ---------- XP SYSTEM ----------

  Future<void> addXP(int amount) async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final curXP = (snap.data()?['xp'] ?? 0) as int;
      final newXP = curXP + amount;

      int newLevel = 1;
      if (newXP >= 10000) newLevel = 7;
      else if (newXP >= 5000) newLevel = 6;
      else if (newXP >= 2500) newLevel = 5;
      else if (newXP >= 1000) newLevel = 4;
      else if (newXP >= 500) newLevel = 3;
      else if (newXP >= 100) newLevel = 2;

      tx.update(ref, {'xp': newXP, 'level': newLevel});
    });
  }

  // ---------- DAILY STREAK ----------

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
          streak = 1;
          _addBadgeInTx(tx, ref, bComebackKid);
        }
      }
      if (streak > best) best = streak;

      final next = cur.toMap()
        ..['currentStreak'] = streak
        ..['highestStreak'] = best
        ..['lastActiveDate'] = today.toIso8601String();
      if (snap.exists) {
        tx.update(ref, next);
      } else {
        tx.set(next);
      }

      _checkAndUnlockStreakBadges(tx, ref, streak);
      _addXPInTx(tx, ref, 10); // +10 XP for daily open

      final hour = now.hour;
      if (hour < 7) _addBadgeInTx(tx, ref, bEarlyBird);
      if (hour >= 23) _addBadgeInTx(tx, ref, bNightOwl);

      if (today.weekday == DateTime.saturday) {
        _addBadgeInTx(tx, ref, 'wknd_sat');
      } else if (today.weekday == DateTime.sunday) {
        _addBadgeInTx(tx, ref, 'wknd_sun');
      }
      _tryUnlockWeekendWarrior(tx, ref);

      return StreakFB.fromMap(next);
    });
  }

  // ---------- WORD VIEW TRACKING (with XP CAP) ----------

  Future<void> trackWordViewed() async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      final count = cur.wordsViewed + 1;

      tx.update(ref, {'wordsViewed': count});

      // Daily XP cap (max 10 slang views/day)
      final today = DateTime.now();
      final lastXPDateStr = snap.data()?['lastWordXPDate'] as String?;
      final lastXPDate = lastXPDateStr != null ? DateTime.tryParse(lastXPDateStr) : null;
      int wordsToday = (snap.data()?['wordsToday'] ?? 0) as int;

      final todayIso = DateTime(today.year, today.month, today.day).toIso8601String();
      final newDay = lastXPDate == null ||
          _justDate(lastXPDate) != _justDate(today);

      if (newDay) wordsToday = 0;

      if (wordsToday < 10) {
        wordsToday += 1;
        tx.update(ref, {
          'wordsToday': wordsToday,
          'lastWordXPDate': todayIso,
        });
        _addXPInTx(tx, ref, 2); // +2 XP per word (capped at 10/day)
      }

      // Badge unlocks
      if (count >= 1) _addBadgeInTx(tx, ref, bFirstWord);
      if (count >= 10) _addBadgeInTx(tx, ref, bWords10);
      if (count >= 50) _addBadgeInTx(tx, ref, bWords50);
      if (count >= 100) _addBadgeInTx(tx, ref, bWords100);
      if (count >= 250) _addBadgeInTx(tx, ref, bWords250);
      if (count >= 500) _addBadgeInTx(tx, ref, bWords500);
    });
  }

  // ---------- SHARE TRACKING ----------

  Future<void> trackShared() async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      final count = cur.sharesCount + 1;

      tx.update(ref, {'sharesCount': count});
      _addXPInTx(tx, ref, 15); // +15 XP per share

      if (count >= 1) _addBadgeInTx(tx, ref, bShared1);
      if (count >= 5) _addBadgeInTx(tx, ref, bShared5);
      if (count >= 25) _addBadgeInTx(tx, ref, bShared25);
      if (count >= 50) _addBadgeInTx(tx, ref, bShared50);
    });
  }

  // ---------- CLAIM REWARDS ----------

  Future<void> claim(int day) async {
    final ref = _doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = StreakFB.fromMap(snap.data());
      if (!cur.rewardsClaimed.contains(day)) {
        final updated = List<int>.from(cur.rewardsClaimed)..add(day);
        tx.update(ref, {'rewardsClaimed': updated});
        _addBadgeInTx(tx, ref, bFirstClaim);
        _addXPInTx(tx, ref, 50); // bonus XP for milestone claim
      }
    });
  }

  // ---------- HELPERS ----------

  void _addBadgeInTx(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    String id,
  ) {
    tx.update(ref, {'badgesUnlocked': FieldValue.arrayUnion([id])});
  }

  void _addXPInTx(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    int amount,
  ) {
    tx.update(ref, {'xp': FieldValue.increment(amount)});
  }

  void _checkAndUnlockStreakBadges(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    int streak,
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
      if (streak >= e.key) _addBadgeInTx(tx, ref, e.value);
    }
  }

  void _tryUnlockWeekendWarrior(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    tx.update(ref, {
      'badgesUnlocked': FieldValue.arrayRemove(['wknd_sat', 'wknd_sun']),
    });
    tx.update(ref, {
      'badgesUnlocked': FieldValue.arrayUnion([bWeekendWarrior]),
    });
  }

  // ---------- STREAM ----------
  Stream<StreakFB> watch() =>
      _doc().snapshots().map((s) => StreakFB.fromMap(s.data()));

  // ---------- DEBUG ----------
  Future<void> debugResetAll() async {
    await _doc().set(StreakFB.initial().toMap());
  }

  Future<void> debugAddBadge(String id) async {
    await _doc().update({'badgesUnlocked': FieldValue.arrayUnion([id])});
  }

  Future<void> debugRemoveBadge(String id) async {
    await _doc().update({'badgesUnlocked': FieldValue.arrayRemove([id])});
  }
}