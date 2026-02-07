import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../streak/streak_banner.dart';
import '../app/slang_providers.dart';
import '../domain/slang_entry.dart';
import '../../../theme/app_theme.dart';

import 'xp_progress_bar.dart';
import '../../streak/streak_controller_firebase.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  String _qRaw = '';
  String _q = '';
  Timer? _debounce;

  final Map<String, String> _hayCache = {};

  final GlobalKey<XPProgressBarState> xpBarKey = GlobalKey<XPProgressBarState>();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
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
        return '${e.term} ${e.meaning} ${e.example} ${e.tags.join(" ")}'
            .toLowerCase();
      });
      return hay.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(slangListProvider);
    final sodAsync = ref.watch(slangOfDayProvider);

    return Container(
      decoration: neonGradientBackground(), // keep your existing background helper
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ✅ Top Header (Replit vibe)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    const _LogoMark(),
                    const SizedBox(width: 10),
                    const Text(
                      'GenZ Dict',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    _GlassPill(
                      onTap: () => context.pushNamed('battle_menu'),
                      child: Row(
                        children: [
                          Icon(Icons.sports_kabaddi_rounded,
                              color: Colors.white.withOpacity(0.85), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Battle',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // XP bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: XPProgressBar(key: xpBarKey),
              ),

              // ✅ Quick actions row (glass chips)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: const [
                    _QuickChip(
                      icon: Icons.emoji_events_rounded,
                      label: 'Badges',
                      routeName: 'badges',
                      accent: Color(0xFFFF4FD8),
                    ),
                    SizedBox(width: 10),
                    _QuickChip(
                      icon: Icons.favorite_rounded,
                      label: 'Favorites',
                      routeName: 'favorites',
                      accent: Color(0xFFA855F7),
                    ),
                    SizedBox(width: 10),
                    _QuickChip(
                      icon: Icons.quiz_rounded,
                      label: 'Quiz',
                      routeName: 'quiz',
                      accent: Color(0xFF22D3EE),
                    ),
                  ],
                ),
              ),

              const StreakBanner(),

              // Slang of day
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: sodAsync.when(
                  data: (e) => _SlangOfDayCard(entry: e),
                  loading: () => _glassShimmer(height: 88),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // ✅ Search bar (glass)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _GlassSearchBar(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                ),
              ),

              Expanded(
                child: listAsync.when(
                  data: (all) {
                    final items = _filter(all, _q);

                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
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
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _SlangTile(entry: items[i]),
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

        // Keep your debug XP button (optional)
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF7C3AED),
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

// ---------- UI helpers (local to this file) ----------

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text(
          'Z',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String routeName;
  final Color accent;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.routeName,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.pushNamed(routeName),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.90),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
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
        color: Colors.white.withOpacity(0.07),
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
            borderSide: BorderSide(
              color: const Color(0xFF7C3AED).withOpacity(0.9),
              width: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// --- Slang of the Day card ---
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

// --- Slang list tile ---
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