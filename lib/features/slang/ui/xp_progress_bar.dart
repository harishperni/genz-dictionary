import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../streak_controller_firebase.dart';

class XPProgressBar extends ConsumerWidget {
  const XPProgressBar({super.key});

  int _levelFromXP(int xp) => (xp / 100).floor() + 1;
  int _xpForNextLevel(int level) => level * 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakFBProvider);
    final xp = streak.xp ?? 0;
    final level = _levelFromXP(xp);
    final nextLevelXP = _xpForNextLevel(level);
    final prevLevelXP = _xpForNextLevel(level - 1);
    final progress = (xp - prevLevelXP) / (nextLevelXP - prevLevelXP);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Level $level',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '$xp / $nextLevelXP XP',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // XP bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF8E2DE2)), // neon purple
            ),
          ),
        ],
      ),
    );
  }
}