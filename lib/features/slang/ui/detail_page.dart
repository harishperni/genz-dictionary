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

enum _MemeTemplate { neon, sunset, monochrome }

class DetailPage extends ConsumerStatefulWidget {
  final String term;
  const DetailPage({super.key, required this.term});

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  final controller = ScreenshotController();
  bool _trackedView = false;
  _MemeTemplate _template = _MemeTemplate.neon;

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(slangByTermProvider(widget.term));
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
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(widget.term),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () async {
                final e = await ref.read(slangByTermProvider(widget.term).future);
                if (e == null) return;
                await _onShareSlang(context, ref, e);
              },
            ),
          ],
        ),
        body: entryAsync.when(
          data: (e) {
            if (e == null) {
              return const Center(
                child: Text('Slang not found.', style: TextStyle(color: Colors.white)),
              );
            }

            // ✅ Track a view ONCE per open for badges/usage
            if (!_trackedView) {
              _trackedView = true;
              Future.microtask(() => ref
                  .read(streakFBProvider.notifier)
                  .trackWordViewed(widget.term));
            }

            return Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      _TemplateChip(
                        label: 'Neon',
                        selected: _template == _MemeTemplate.neon,
                        onTap: () => setState(() => _template = _MemeTemplate.neon),
                      ),
                      const SizedBox(width: 8),
                      _TemplateChip(
                        label: 'Sunset',
                        selected: _template == _MemeTemplate.sunset,
                        onTap: () => setState(() => _template = _MemeTemplate.sunset),
                      ),
                      const SizedBox(width: 8),
                      _TemplateChip(
                        label: 'Mono',
                        selected: _template == _MemeTemplate.monochrome,
                        onTap: () =>
                            setState(() => _template = _MemeTemplate.monochrome),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _VisibleContent(entry: e, controller: controller)),
              ],
            );
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
    final imgBytes = await controller.captureFromWidget(
      _ShareCard(entry: e, template: _template),
      pixelRatio: ui.window.devicePixelRatio.clamp(2.0, 3.0),
    );

    final file = XFile.fromData(
      imgBytes,
      name: '${e.term}.png',
      mimeType: 'image/png',
    );

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
  final _MemeTemplate template;

  const _ShareCard({required this.entry, required this.template});

  @override
  Widget build(BuildContext context) {
    final bg = switch (template) {
      _MemeTemplate.neon => const Color(0xFF0D1021),
      _MemeTemplate.sunset => const Color(0xFF2B0C2F),
      _MemeTemplate.monochrome => const Color(0xFF121212),
    };
    final accent = switch (template) {
      _MemeTemplate.neon => const Color(0xFF22D3EE),
      _MemeTemplate.sunset => const Color(0xFFFF7B54),
      _MemeTemplate.monochrome => const Color(0xFFE5E7EB),
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.all(24),
      width: 1080,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardBody(
              entry: entry,
              titleStyle: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
              meaningStyle: const TextStyle(fontSize: 30, height: 1.25),
              exampleStyle: const TextStyle(fontSize: 28),
              tagChipOpacity: 0.12,
              emojiSize: 44,
              quoteIcon: Icons.format_quote_rounded,
            ),
            const SizedBox(height: 20),
            Text(
              'Made with Gen Z Dictionary • genzdictionary.app',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF22D3EE).withOpacity(0.28)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(chipOpacity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('#$t',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
