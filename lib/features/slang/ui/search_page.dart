// lib/features/slang/ui/search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../streak/streak_banner.dart';
import '../app/slang_providers.dart';
import '../domain/slang_entry.dart';
import '../../../theme/app_theme.dart';

// XP bar with animated popup
import 'xp_progress_bar.dart';

// For XP updates and debug testing
import '../../streak/streak_controller_firebase.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  // Raw text as user types
  String _qRaw = '';

  // Debounced query actually used to filter
  String _q = '';

  Timer? _debounce;

  // Cache: term -> precomputed searchable text (lowercased)
  final Map<String, String> _hayCache = {};

  // Key to trigger XP popup animation
  final GlobalKey<XPProgressBarState> xpBarKey = GlobalKey<XPProgressBarState>();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _qRaw = v;

    // Debounce filtering to avoid UI lag while typing
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _q = _qRaw);
    });
  }

  List<SlangEntry> _filter(List<SlangEntry> all, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return all;

    // Build haystack cache once per term (fast search later)
    // NOTE: uses term as key; if you ever have duplicates, switch key to sys id.
    for (final e in all) {
      _hayCache.putIfAbsent(e.term, () {
        return ('${e.term} ${e.meaning} ${e.example} ${e.tags.join(" ")}')
            .toLowerCase();
      });
    }

    return all.where((e) {
      final hay = _hayCache[e.term] ?? '';
      return hay.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(slangListProvider);
    final sodAsync = ref.watch(slangOfDayProvider);

    return Container(
      decoration: neonGradientBackground(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Gen Z Dictionary'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 XP Progress Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: XPProgressBar(key: xpBarKey),
              ),

              // 🌟 Quick Actions Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF5A2DF5),
                        Color(0xFF6B34F0),
                        Color(0xFF7C3AED),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      _TopQuickAction(
                        icon: Icons.emoji_events_rounded,
                        label: 'Badges',
                        routeName: 'badges',
                      ),
                      _TopDivider(),
                      _TopQuickAction(
                        icon: Icons.favorite_rounded,
                        label: 'Favorites',
                        routeName: 'favorites',
                      ),
                      _TopDivider(),
                      _TopQuickAction(
                        icon: Icons.quiz_rounded,
                        label: 'Quiz',
                        routeName: 'quiz',
                      ),
                      _TopDivider(),
                      _TopQuickAction(
                        icon: Icons.sports_kabaddi_rounded,
                        label: 'Battle',
                        routeName: 'battle_menu',
                      ),
                    ],
                  ),
                ),
              ),

              // 🔥 Daily Streak Banner
              const StreakBanner(),

              // ⭐️ Slang of the Day
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: sodAsync.when(
                  data: (e) => _SlangOfDayCard(entry: e),
                  loading: () => _glassShimmer(height: 88),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // 🔎 Search Field (debounced)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Search slang, meaning, tags…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              // 📜 Results
              Expanded(
                child: listAsync.when(
                  data: (all) {
                    // Clear cache if dataset changed drastically (optional safety)
                    // If you never mutate slangs at runtime, you can remove this.
                    if (_hayCache.length > all.length + 50) {
                      _hayCache.clear();
                    }

                    final items = _filter(all, _q);

                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No results for "${_q.trim()}"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _SlangTile(entry: items[i]),
                    );
                  },
                  loading: () => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: 10,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _glassShimmer(height: 64),
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),

        // 🧪 XP Debug Button (popup animation)
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.deepPurpleAccent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add XP'),
          onPressed: () async {
            const addedXP = 50;
            final notifier = ref.read(streakFBProvider.notifier);
            await notifier.debugAddXP(addedXP);
            xpBarKey.currentState?.showXPGain(addedXP);
          },
        ),
      ),
    );
  }
}

// === Quick action helpers ===
class _TopQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String routeName;

  const _TopQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.pushNamed(routeName),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.95),
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopDivider extends StatelessWidget {
  const _TopDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withOpacity(0.12),
    );
  }
}

// === Slang of the Day card ===
// NOTE: slangOfDayProvider now returns SlangEntry? (nullable)
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: glassCard(),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Text('⭐️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Slang of the Day: ${e.term}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

// === Slang list tile ===
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: glassCard(),
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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.term,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

// === Simple shimmer placeholder ===
Widget _glassShimmer({double height = 60}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
  );
}