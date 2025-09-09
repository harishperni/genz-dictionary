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
    final listAsync = ref.watch(slangListProvider);
    final fav = ref.watch(favoritesProvider);

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
                fav.contains(widget.term) ? Icons.favorite : Icons.favorite_border,
              ),
              onPressed: () => ref.read(favoritesProvider.notifier).toggle(widget.term),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _shareCard,
            ),
          ],
        ),
        body: listAsync.when(
          data: (list) {
            final e = list.firstWhere(
              (s) => s.term.toLowerCase() == widget.term.toLowerCase(),
              orElse: () => list.first,
            );

            // Track a view ONCE per open for badges/usage
            if (!_trackedView) {
              _trackedView = true;
              Future.microtask(() =>
                  ref.read(streakFBProvider.notifier).trackWordViewed());
            }

            return _VisibleContent(entry: e, controller: controller);
          },
          error: (e, st) => Center(child: Text('Error: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _shareCard() async {
    // Build a dedicated, opaque share card (no rounded corners, no transparent bg)
    final list = await ref.read(slangListProvider.future);
    final e = list.firstWhere(
      (s) => s.term.toLowerCase() == widget.term.toLowerCase(),
      orElse: () => list.first,
    );

    // Render offscreen with a solid background (prevents checkerboard)
    final imgBytes = await controller.captureFromWidget(
      _ShareCard(entry: e),
      // keep it crisp on high-dpi devices
      pixelRatio: ui.window.devicePixelRatio.clamp(2.0, 3.0),
    );

    // Track share for badges
    await ref.read(streakFBProvider.notifier).trackShared();

    final file = XFile.fromData(
      imgBytes,
      name: '${e.term}.png',
      mimeType: 'image/png',
    );
    await Share.shareXFiles([file], text: 'Gen Z Dictionary: ${e.term}');
  }
}

/// On-screen content (glass card, rounded corners) — what the user sees.
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

/// Off-screen, share-ready card (RECTANGULAR, OPAQUE, no rounded corners).
class _ShareCard extends StatelessWidget {
  final SlangEntry entry;
  const _ShareCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    // Use a fixed width; height wraps content. Solid background (no transparency).
    // Pick a neutral dark to match the app vibe but keep text readable.
    const bg = Color(0xFF0D1021); // deep navy
    return Container(
      color: bg,
      padding: const EdgeInsets.all(24),
      width: 1080, // good export width; keeps text sharp
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: _CardBody(
          entry: entry,
          // Override styles slightly for export to pop better on dark bg
          titleStyle: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
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

  // Optional style overrides (used by share card)
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
    final tStyle = titleStyle ?? const TextStyle(fontSize: 28, fontWeight: FontWeight.w800);
    final mStyle = meaningStyle ?? const TextStyle(fontSize: 16);
    final exStyle = exampleStyle ?? const TextStyle(fontSize: 16);
    final chipOpacity = tagChipOpacity ?? 0.08;
    final emojiSz = emojiSize ?? 22.0;
    final qIcon = quoteIcon ?? Icons.format_quote_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(entry.term, style: tStyle),
        const SizedBox(height: 8),
        // Meaning
        Text(entry.meaning, style: mStyle),
        const SizedBox(height: 12),
        // Emojis row
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
        // Example bubble
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
        // Tags
        if (entry.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.tags
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(chipOpacity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('#$t', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}