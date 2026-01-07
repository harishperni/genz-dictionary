// lib/features/slang/ui/detail_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../app/slang_providers.dart';
import '../domain/slang_entry.dart';
import '../../../theme/app_theme.dart';

// ✅ for usage/badges tracking
import '../../streak/streak_controller_firebase.dart';

class DetailPage extends ConsumerStatefulWidget {
  final String term;
  const DetailPage({super.key, required this.term});

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  final controller = ScreenshotController();
  bool _trackedView = false;

  @override
  Widget build(BuildContext context) {
    // 🔥 Warm the slang map cache (no await, no rebuild)
    ref.read(slangMapProvider.future);
    // ✅ O(1) lookup provider (fast)
    final entryAsync = ref.watch(slangByTermProvider(widget.term));
    final fav = ref.watch(favoritesProvider);

    // (Optional) kick off map/list load early in case we arrived here fast
    // This is cheap because it’s cached; it just ensures it’s in-memory.
    ref.read(slangMapProvider.future);

    return Container(
      decoration: neonGradientBackground(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.term),
          actions: [
            IconButton(
              tooltip: 'Favorite',
              icon: Icon(
                fav.contains(widget.term)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(widget.term),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () async {
                // ✅ Fetch the one entry (not the full list)
                final e = await ref.read(slangByTermProvider(widget.term).future);

                if (!mounted) return;
                if (e == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Slang not found.')),
                  );
                  return;
                }

                await _onShareSlang(context, ref, e);
              },
            ),
          ],
        ),
        body: entryAsync.when(
          data: (e) {
            if (e == null) {
              return const Center(child: Text('Slang not found.'));
            }

            // ✅ Track a view ONCE per open for badges/usage
            if (!_trackedView) {
              _trackedView = true;
              Future.microtask(() => ref
                  .read(streakFBProvider.notifier)
                  .trackWordViewed(widget.term));
            }

            return _VisibleContent(entry: e, controller: controller);
          },
          error: (e, st) => Center(child: Text('Error: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  // ✅ Clean, single share function with XP check
  Future<void> _onShareSlang(
    BuildContext context,
    WidgetRef ref,
    SlangEntry e,
  ) async {
    // Capture the card as an image (offscreen)
    final imgBytes = await controller.captureFromWidget(
      _ShareCard(entry: e),
      pixelRatio: ui.window.devicePixelRatio.clamp(2.0, 3.0),
    );

    final file = XFile.fromData(
      imgBytes,
      name: '${e.term}.png',
      mimeType: 'image/png',
    );

    // Use ShareResult to ensure real share
    final result = await Share.shareXFiles(
      [file],
      text: 'Gen Z Dictionary: ${e.term}',
    );

    if (result.status == ShareResultStatus.success) {
      await ref.read(streakFBProvider.notifier).trackShared();
    }
  }
}

/// On-screen content (glass card, rounded corners)
class _VisibleContent extends StatelessWidget {
  final SlangEntry entry;
  final ScreenshotController controller;

  const _VisibleContent({required this.entry, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Screenshot(
        controller: controller,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: glassCard(),
          child: _CardBody(entry: entry),
        ),
      ),
    );
  }
}

/// Off-screen, share-ready card (RECTANGULAR, OPAQUE)
class _ShareCard extends StatelessWidget {
  final SlangEntry entry;
  const _ShareCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D1021); // dark navy background
    return Container(
      color: bg,
      padding: const EdgeInsets.all(24),
      width: 1080,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: _CardBody(
          entry: entry,
          titleStyle:
              const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
          meaningStyle: const TextStyle(fontSize: 30, height: 1.25),
          exampleStyle: const TextStyle(fontSize: 28),
          tagChipOpacity: 0.12,
          emojiSize: 44,
          quoteIcon: Icons.format_quote_rounded,
        ),
      ),
    );
  }
}

/// Shared body between visible and share variants.
class _CardBody extends StatelessWidget {
  final SlangEntry entry;
  final TextStyle? titleStyle;
  final TextStyle? meaningStyle;
  final TextStyle? exampleStyle;
  final double? tagChipOpacity;
  final double? emojiSize;
  final IconData? quoteIcon;

  const _CardBody({
    required this.entry,
    this.titleStyle,
    this.meaningStyle,
    this.exampleStyle,
    this.tagChipOpacity,
    this.emojiSize,
    this.quoteIcon,
  });

  @override
  Widget build(BuildContext context) {
    final tStyle =
        titleStyle ?? const TextStyle(fontSize: 28, fontWeight: FontWeight.w800);
    final mStyle = meaningStyle ?? const TextStyle(fontSize: 16);
    final exStyle = exampleStyle ?? const TextStyle(fontSize: 16);
    final chipOpacity = tagChipOpacity ?? 0.08;
    final emojiSz = emojiSize ?? 22.0;
    final qIcon = quoteIcon ?? Icons.format_quote_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.term, style: tStyle),
        const SizedBox(height: 8),
        Text(entry.meaning, style: mStyle),
        const SizedBox(height: 12),
        if (entry.emojis.isNotEmpty)
          Row(
            children: entry.emojis
                .take(5)
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(e, style: TextStyle(fontSize: emojiSz)),
                    ))
                .toList(),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(qIcon),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.example, style: exStyle)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (entry.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.tags
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(chipOpacity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$t',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}