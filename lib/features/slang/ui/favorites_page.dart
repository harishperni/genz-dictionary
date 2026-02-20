import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../app/slang_providers.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).toList()..sort();

    return Container(
      decoration: neonGradientBackground(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Favorites'),
        ),
        body: favs.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: favs.length,
                itemBuilder: (ctx, i) {
                  final term = favs[i];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: InkWell(
                      onTap: () => context.pushNamed(
                        'detail',
                        pathParameters: {'term': Uri.encodeComponent(term)},
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: glassCard(),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite,
                                color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                term,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Share',
                              icon: const Icon(Icons.share_rounded),
                              onPressed: () => context.pushNamed(
                                'detail',
                                pathParameters: {'term': Uri.encodeComponent(term)},
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove from favorites',
                              icon: const Icon(Icons.favorite_border),
                              onPressed: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggle(term),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: glassCard(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No favorites yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart on any term to save it here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Browse Slang'),
            ),
          ],
        ),
      ),
    );
  }
}
