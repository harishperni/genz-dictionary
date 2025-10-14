import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../streak/streak_banner.dart'; // shared banner widget
import '../app/slang_providers.dart';
import '../domain/slang_entry.dart';
import '../../../theme/app_theme.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SlangEntry> _filter(List<SlangEntry> all, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((e) {
      final hay =
          '${e.term} ${e.meaning} ${e.example} ${e.tags.join(" ")}'.toLowerCase();
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🌟 Quick actions row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF5A2DF5),
                            Color(0xFF6B34F0),
                            Color(0xFF7C3AED)
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
                        children: [
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
                        ],
                      ),
                    ),
                  ),

                  // 🔥 Daily Streak banner
                  const StreakBanner(),

                  // ⭐️ Slang of the Day
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: sodAsync.when(
                      data: (e) => _SlangOfDayCard(entry: e),
                      loading: () => _glassShimmer(height: 88),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                  ),

                  // 🔎 Search field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _q = v),
                      decoration: InputDecoration(
                        hintText: 'Search slang, meaning, tags…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  // 📜 Results list (scrollable inside a fixed height region)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: listAsync.when(
                      data: (all) {
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = items[i];
                            return _SlangTile(entry: e);
                          },
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
                      error: (e, st) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    required this.icon,
    required this.label,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Colors.white;
    final textColor = Colors.white.withOpacity(0.95);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.pushNamed(routeName),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
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
  const _TopDivider();

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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
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
            // Leading emoji cluster
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
            // Term + meaning
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.term,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    entry.meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                    ),
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