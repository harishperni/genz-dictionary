import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart'; // 2 levels up (features → lib → theme)
import 'streak_controller_firebase.dart';
import 'streak_service_firebase.dart';

class BadgesPage extends ConsumerWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakFBProvider);

    return Container(
      decoration: neonGradientBackground(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Badges'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Summary card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: glassCard(),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('🏅', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Streak: ${s.currentStreak} • Best: ${s.highestStreak}\n'
                          'Words: ${s.wordsViewed} • Shares: ${s.sharesCount}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Badges grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _allBadges.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (_, i) {
                    final b = _allBadges[i];
                    final unlocked = s.badgesUnlocked.contains(b.id);
                    return _BadgeCard(badge: b, unlocked: unlocked);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeSpec {
  final String id;
  final String title;
  final String desc;
  final String emoji;
  const _BadgeSpec({
    required this.id,
    required this.title,
    required this.desc,
    required this.emoji,
  });
}

// Catalog of badges
const _allBadges = <_BadgeSpec>[
  // Streak
  _BadgeSpec(id: StreakServiceFirebase.bStreak3,   title: 'Starter Streak',  desc: '3 days in a row',    emoji: '🔥'),
  _BadgeSpec(id: StreakServiceFirebase.bStreak7,   title: 'Weekly Warrior',  desc: '7 days in a row',    emoji: '🏆'),
  _BadgeSpec(id: StreakServiceFirebase.bStreak14,  title: 'Two-Week Champ',  desc: '14 days in a row',   emoji: '⚡️'),
  _BadgeSpec(id: StreakServiceFirebase.bStreak30,  title: 'Month Master',    desc: '30 days in a row',   emoji: '👑'),
  _BadgeSpec(id: StreakServiceFirebase.bStreak60,  title: 'Diamond Disc.',   desc: '60 days in a row',   emoji: '💎'),
  _BadgeSpec(id: StreakServiceFirebase.bStreak100, title: 'Century Club',    desc: '100 days in a row',  emoji: '🥇'),
  _BadgeSpec(id: StreakServiceFirebase.bStreak365, title: 'Legendary',       desc: '365 days in a row',  emoji: '🌍'),

  // Usage
  _BadgeSpec(id: StreakServiceFirebase.bFirstWord, title: 'Newbie Wordsmith', desc: 'Viewed your 1st word', emoji: '✍️'),
  _BadgeSpec(id: StreakServiceFirebase.bWords10,   title: 'Curious Cat',      desc: 'Viewed 10 words',     emoji: '🐱'),
  _BadgeSpec(id: StreakServiceFirebase.bWords50,   title: 'Dictionary Diver', desc: 'Viewed 50 words',     emoji: '📚'),
  _BadgeSpec(id: StreakServiceFirebase.bWords100,  title: 'Walking Dict.',    desc: 'Viewed 100 words',    emoji: '🧠'),

  // Behavior / Misc
  _BadgeSpec(id: StreakServiceFirebase.bFirstClaim,     title: 'Treasure Hunter',  desc: 'Claimed a reward',      emoji: '🗝️'),
  _BadgeSpec(id: StreakServiceFirebase.bShared1,        title: 'Spreader',         desc: 'Shared a slang',        emoji: '📢'),
  _BadgeSpec(id: StreakServiceFirebase.bEarlyBird,      title: 'Early Bird',       desc: 'Opened app before 7am', emoji: '🌞'),
  _BadgeSpec(id: StreakServiceFirebase.bNightOwl,       title: 'Night Owl',        desc: 'Opened app after 11pm', emoji: '🌙'),
  _BadgeSpec(id: StreakServiceFirebase.bWeekendWarrior, title: 'Weekend Warrior',  desc: 'Active Sat & Sun',      emoji: '🎉'),
  _BadgeSpec(id: StreakServiceFirebase.bComebackKid,    title: 'Comeback Kid',     desc: 'Returned after a break',emoji: '🔄'),
];

class _BadgeCard extends StatelessWidget {
  final _BadgeSpec badge;
  final bool unlocked;
  const _BadgeCard({required this.badge, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withOpacity(0.45);

    return Container(
      decoration: glassCard(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.55,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 36)),
          ),
          const SizedBox(height: 8),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            badge.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: unlocked ? Colors.white : muted,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (unlocked ? Colors.white : Colors.white.withOpacity(0.08))
                  .withOpacity(unlocked ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(unlocked ? 0.25 : 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  size: 16,
                  color: unlocked ? Colors.white : muted,
                ),
                const SizedBox(width: 6),
                Text(
                  unlocked ? 'Unlocked' : 'Locked',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: unlocked ? Colors.white : muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}