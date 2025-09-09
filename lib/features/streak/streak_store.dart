import 'package:shared_preferences/shared_preferences.dart';

class StreakData {
  final int streakCount;         // current streak
  final DateTime? lastOpenDate;  // last day we counted
  final List<int> claimed;       // milestones already claimed (e.g., [3,7])

  const StreakData({required this.streakCount, required this.lastOpenDate, required this.claimed});

  StreakData copyWith({int? streakCount, DateTime? lastOpenDate, List<int>? claimed}) {
    return StreakData(
      streakCount: streakCount ?? this.streakCount,
      lastOpenDate: lastOpenDate ?? this.lastOpenDate,
      claimed: claimed ?? this.claimed,
    );
  }
}

class StreakStore {
  static const _kStreak = 'streak_count';
  static const _kLastOpen = 'streak_last_open_iso';
  static const _kClaimed = 'streak_claimed'; // CSV: "3,7"

  Future<StreakData> load() async {
    final sp = await SharedPreferences.getInstance();
    final count = sp.getInt(_kStreak) ?? 0;
    final lastIso = sp.getString(_kLastOpen);
    final lastDate = (lastIso == null || lastIso.isEmpty) ? null : DateTime.tryParse(lastIso);
    final claimedCsv = sp.getString(_kClaimed) ?? '';
    final claimed = claimedCsv.isEmpty ? <int>[] : claimedCsv.split(',').map((e) => int.tryParse(e) ?? 0).where((x) => x > 0).toList();
    return StreakData(streakCount: count, lastOpenDate: lastDate, claimed: claimed);
  }

  Future<void> save(StreakData d) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kStreak, d.streakCount);
    await sp.setString(_kLastOpen, (d.lastOpenDate ?? DateTime.now()).toIso8601String());
    await sp.setString(_kClaimed, d.claimed.join(','));
  }
}