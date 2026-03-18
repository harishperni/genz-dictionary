import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_theme.dart';
import '../../streak/streak_banner.dart';
import '../../streak/streak_controller_firebase.dart';
import '../app/slang_providers.dart';
import '../domain/slang_entry.dart';
import 'xp_progress_bar.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _challengeController = TextEditingController();
  final Map<String, String> _hayCache = {};
  final GlobalKey<XPProgressBarState> xpBarKey = GlobalKey<XPProgressBarState>();

  String _qRaw = '';
  String _q = '';
  Timer? _debounce;

  bool _challengeDoneToday = false;
  bool _loadingChallengeState = true;

  @override
  void initState() {
    super.initState();
    _loadChallengeState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _challengeController.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'daily_challenge_done_${now.year}_$m$d';
  }

  Future<void> _loadChallengeState() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_todayKey()) ?? false;
    if (!mounted) return;
    setState(() {
      _challengeDoneToday = done;
      _loadingChallengeState = false;
    });
  }

  Future<void> _completeChallenge(SlangEntry entry, String sentence) async {
    if (_challengeDoneToday) return;
    final s = sentence.trim();
    if (s.length < 8 || !s.toLowerCase().contains(entry.term.toLowerCase())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Write a sentence using "${entry.term}" first.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayKey(), true);
    await prefs.setString('${_todayKey()}_text', s);

    if (!mounted) return;
    setState(() => _challengeDoneToday = true);

    await ref.read(streakFBProvider.notifier).trackWordViewed(entry.term);
    await ref.read(streakFBProvider.notifier).trackDailyChallengeComplete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Challenge complete: +XP for ${entry.term}'),
      ),
    );
  }

  void _onQueryChanged(String v) {
    _qRaw = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _q = _qRaw);
    });
  }

  List<SlangEntry> _filter(List<SlangEntry> all, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return all;

    if (_hayCache.length > all.length + 50) _hayCache.clear();

    return all.where((e) {
      final hay = _hayCache.putIfAbsent(e.term, () {
        return '${e.term} ${e.meaning} ${e.example} ${e.tags.join(" ")}'.toLowerCase();
      });
      return hay.contains(query);
    }).toList();
  }

  List<String> _topTags(List<SlangEntry> all) {
    final counts = <String, int>{};
    for (final e in all) {
      for (final tag in e.tags) {
        final t = tag.trim().toLowerCase();
        if (t.isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(8).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(slangListProvider);
    final sodAsync = ref.watch(slangOfDayProvider);

    return Stack(
      children: [
        Container(decoration: neonGradientBackground()),
        Positioned(
          top: -90,
          left: -70,
          child: _orb(const Color(0xFF2DD4BF).withOpacity(0.14), 220),
        ),
        Positioned(
          top: 120,
          right: -90,
          child: _orb(const Color(0xFFFF6B9A).withOpacity(0.13), 240),
        ),
        Positioned(
          bottom: -80,
          left: 60,
          child: _orb(const Color(0xFF60A5FA).withOpacity(0.11), 220),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    children: [
                      const _LogoMark(),
                      const SizedBox(width: 10),
                      const Text(
                        'GENZ DICTIONARY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      _GlassPill(
                        onTap: () => context.pushNamed('battle_menu'),
                        child: const Row(
                          children: [
                            Icon(Icons.sports_kabaddi_rounded,
                                color: Color(0xFF90F3FF), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Battle',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: XPProgressBar(key: xpBarKey),
                ),
                Expanded(
                  child: listAsync.when(
                    data: (all) {
                      final items = _filter(all, _q);
                      final tags = _topTags(all);

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
                        children: [
                          _HeroCard(wordCount: all.length),
                          const SizedBox(height: 12),
                          _ActionScroller(
                            onTapBadges: () => context.pushNamed('badges'),
                            onTapFavorites: () => context.pushNamed('favorites'),
                            onTapQuiz: () => context.pushNamed('quiz'),
                            onTapLeaderboard: () => context.pushNamed('leaderboard'),
                            onTapSubmitSlang: () => context.pushNamed('submit_slang'),
                            onTapHub: () => context.pushNamed('growth_hub'),
                          ),
                          const SizedBox(height: 12),
                          const StreakBanner(),
                          const SizedBox(height: 8),
                          sodAsync.when(
                            data: (e) => _SlangOfDayCard(entry: e),
                            loading: () => _glassShimmer(height: 88),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 10),
                          if (_loadingChallengeState)
                            _glassShimmer(height: 108)
                          else
                            _DailyChallengeCard(
                              entry: all.isEmpty
                                  ? null
                                  : all[(DateTime.now().year * 10000 +
                                          DateTime.now().month * 100 +
                                          DateTime.now().day) %
                                      all.length],
                              done: _challengeDoneToday,
                              inputController: _challengeController,
                              onComplete: (entry) => _completeChallenge(
                                entry,
                                _challengeController.text,
                              ),
                            ),
                          const SizedBox(height: 10),
                          _TrendingTags(
                            tags: tags,
                            onTapTag: (tag) {
                              _controller.text = tag;
                              _onQueryChanged(tag);
                            },
                          ),
                          const SizedBox(height: 10),
                          _GlassSearchBar(
                            controller: _controller,
                            onChanged: _onQueryChanged,
                          ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No results for "${_q.trim()}"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            ...List.generate(items.length, (i) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
                                child: _SlangTile(entry: items[i]),
                              );
                            }),
                        ],
                      );
                    },
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: 10,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _glassShimmer(height: 70),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0EA5E9),
            icon: const Icon(Icons.auto_graph_rounded, color: Colors.white),
            label: const Text('Boost XP'),
            onPressed: () async {
              const addedXP = 50;
              final notifier = ref.read(streakFBProvider.notifier);
              await notifier.debugAddXP(addedXP);
              xpBarKey.currentState?.showXPGain(addedXP);
            },
          ),
        ),
      ],
    );
  }

  Widget _orb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 90,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFF43F5E), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text(
          'Z',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int wordCount;

  const _HeroCard({required this.wordCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x44FB7185), Color(0x4422D3EE), Color(0x335A67D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Talk less basic. Speak internet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$wordCount slang terms, quizzes, battles, streaks, and daily missions.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionScroller extends StatelessWidget {
  final VoidCallback onTapBadges;
  final VoidCallback onTapFavorites;
  final VoidCallback onTapQuiz;
  final VoidCallback onTapLeaderboard;
  final VoidCallback onTapSubmitSlang;
  final VoidCallback onTapHub;

  const _ActionScroller({
    required this.onTapBadges,
    required this.onTapFavorites,
    required this.onTapQuiz,
    required this.onTapLeaderboard,
    required this.onTapSubmitSlang,
    required this.onTapHub,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionChip(label: 'Badges', icon: Icons.emoji_events_rounded, accent: const Color(0xFFF43F5E), onTap: onTapBadges),
          const SizedBox(width: 8),
          _ActionChip(label: 'Favorites', icon: Icons.favorite_rounded, accent: const Color(0xFFFB7185), onTap: onTapFavorites),
          const SizedBox(width: 8),
          _ActionChip(label: 'Quiz', icon: Icons.quiz_rounded, accent: const Color(0xFF22D3EE), onTap: onTapQuiz),
          const SizedBox(width: 8),
          _ActionChip(label: 'Leaderboard', icon: Icons.leaderboard_rounded, accent: const Color(0xFF38BDF8), onTap: onTapLeaderboard),
          const SizedBox(width: 8),
          _ActionChip(label: 'Submit Slang', icon: Icons.edit_note_rounded, accent: const Color(0xFF34D399), onTap: onTapSubmitSlang),
          const SizedBox(width: 8),
          _ActionChip(label: 'GenZ+', icon: Icons.auto_awesome_rounded, accent: const Color(0xFFFDE047), onTap: onTapHub),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.94),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: child,
      ),
    );
  }
}

class _GlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _GlassSearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Search slang, meaning, tags…',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.70)),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF22D3EE),
              width: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _SlangOfDayCard extends StatelessWidget {
  final SlangEntry? entry;

  const _SlangOfDayCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => context.pushNamed(
        'detail',
        pathParameters: {'term': Uri.encodeComponent(e.term)},
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Text('⭐️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Slang of the Day: ${e.term}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.85)),
          ],
        ),
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  final SlangEntry? entry;
  final bool done;
  final TextEditingController inputController;
  final ValueChanged<SlangEntry> onComplete;

  const _DailyChallengeCard({
    required this.entry,
    required this.done,
    required this.inputController,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0x1A34D399),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Color(0xFF34D399)),
              SizedBox(width: 8),
              Text(
                'Daily Challenge',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use "${e.term}" in a sentence and tap complete to claim XP.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: inputController,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Type your sentence...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: done ? null : () => onComplete(e),
              icon: Icon(done ? Icons.check_rounded : Icons.task_alt_rounded),
              label: Text(done ? 'Completed Today' : 'Mark Complete'),
              style: FilledButton.styleFrom(
                backgroundColor: done ? const Color(0xFF64748B) : const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingTags extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onTapTag;

  const _TrendingTags({required this.tags, required this.onTapTag});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending right now',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (t) => InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onTapTag(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SlangTile extends StatelessWidget {
  final SlangEntry entry;

  const _SlangTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(
        'detail',
        pathParameters: {'term': Uri.encodeComponent(entry.term)},
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: entry.emojis.take(2).map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.term,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.85)),
          ],
        ),
      ),
    );
  }
}

Widget _glassShimmer({double height = 60}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
  );
}
