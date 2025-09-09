import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⬇️ use the Firebase-backed controller (not the old one)
import 'streak_controller_firebase.dart';

class StreakBanner extends ConsumerWidget {
  const StreakBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // State & controller from Firebase version
    final streak = ref.watch(streakFBProvider);
    final ctrl = ref.read(streakFBProvider.notifier);

    final days = streak.currentStreak;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Streak: $days day${days == 1 ? '' : 's'} • Best: ${streak.highestStreak}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (ctrl.hasUnclaimed)
            FilledButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reward Unlocked 🎁'),
                    content: Text('Nice! Day $days streak. You unlocked a special card theme.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                await ctrl.claimTodayReward();
              },
              child: const Text('Claim'),
            ),
        ],
      ),
    );
  }
}