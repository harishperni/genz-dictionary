import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'streak_controller_firebase.dart';

class DebugStreakPanel extends ConsumerStatefulWidget {
  const DebugStreakPanel({super.key});

  @override
  ConsumerState<DebugStreakPanel> createState() => _DebugStreakPanelState();
}

class _DebugStreakPanelState extends ConsumerState<DebugStreakPanel> {
  final _badgeController = TextEditingController();
  final _dayController = TextEditingController();

  @override
  void dispose() {
    _badgeController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(streakFBProvider);
    final ctrl = ref.read(streakFBProvider.notifier);
    final service = ctrl.service;

    return Scaffold(
      appBar: AppBar(title: const Text('🧪 Debug Streak Panel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Current Data ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Current Firebase Streak Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text('Current Streak: ${state.currentStreak}'),
                  Text('Highest Streak: ${state.highestStreak}'),
                  Text('Last Active: ${state.lastActiveDate ?? '—'}'),
                  Text('Words Viewed: ${state.wordsViewed}'),
                  Text('Shares Count: ${state.sharesCount}'),
                  Text('Badges: ${state.badgesUnlocked.join(", ")}'),
                  Text('Claimed Rewards: ${state.rewardsClaimed.join(", ")}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Streak Tools ---
          const Text('🔥 Streak Tools',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: ctrl.recomputeToday,
            child: const Text('Recompute Today (touchToday)'),
          ),
          ElevatedButton(
            onPressed: () => ctrl.debugJumpToDayAndTouch(3),
            child: const Text('Jump to Day 3'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (state.rewardsClaimed.isNotEmpty) {
                final last = state.rewardsClaimed.last;
                await ctrl.debugUnclaimDay(last);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unclaimed day $last')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No rewards to unclaim.')),
                );
              }
            },
            child: const Text('Unclaim Last Reward'),
          ),

          const Divider(height: 32),

          // --- Manual Badge Tools ---
          const Text('🏅 Badge Tools',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _badgeController,
            decoration: const InputDecoration(
              labelText: 'Badge ID',
              hintText: 'e.g. early_bird, words_10, streak_7',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final id = _badgeController.text.trim();
                    if (id.isEmpty) return;
                    await service.debugAddBadge(id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Added badge "$id"')),
                    );
                  },
                  child: const Text('Add Badge'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final id = _badgeController.text.trim();
                    if (id.isEmpty) return;
                    await service.debugRemoveBadge(id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Removed badge "$id"')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text('Remove Badge'),
                ),
              ),
            ],
          ),

          const Divider(height: 32),

          // --- Jump to Specific Day ---
          const Text('📆 Jump to Any Day',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _dayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target day number',
              hintText: 'e.g. 7',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final day = int.tryParse(_dayController.text.trim());
              if (day == null) return;
              await ctrl.debugJumpToDayAndTouch(day);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Jumped to day $day')),
              );
            },
            child: const Text('Simulate Day & Touch'),
          ),

          const Divider(height: 32),

          // --- Reset Everything ---
          const Text('🧹 Reset All Progress',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Reset'),
                  content: const Text(
                      'This will clear your streak, badges, and counters. Continue?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Reset')),
                  ],
                ),
              );
              if (confirmed != true) return;

              await service.debugResetAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🧹 Reset complete!')),
              );
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Reset All Progress'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }
}