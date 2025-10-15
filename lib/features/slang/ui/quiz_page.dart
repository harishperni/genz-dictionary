// lib/features/slang/ui/quiz_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../theme/app_theme.dart';
import '../quiz/quiz_controller.dart';
import '../app/slang_providers.dart';

// ✅ Add this import for XP tracking
import '../../streak/streak_controller_firebase.dart';

class QuizPage extends ConsumerWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(slangListProvider);
    return Container(
      decoration: neonGradientBackground(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Slang Quiz')),
        body: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (_) => const _QuizBody(),
        ),
      ),
    );
  }
}

class _QuizBody extends ConsumerWidget {
  const _QuizBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizControllerProvider);
    final ctrl = ref.read(quizControllerProvider.notifier);

    if (state.questions.isEmpty) {
      return const Center(child: Text('Not enough data for a quiz.'));
    }

    if (state.finished) {
      return _Finished(
        score: state.score,
        total: state.questions.length,
        onRetry: () {
          final all = ref.read(slangListProvider).value ?? [];
          final len = ref.read(quizLengthProvider);
          ctrl.restart(all, length: len);
        },
      );
    }

    final q = state.questions[state.index];
    final isAnswered = state.selected != null;
    final correct = q.correct;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress + score
          Row(
            children: [
              Text('Q ${state.index + 1}/${state.questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Score: ${state.score}'),
            ],
          ),
          const SizedBox(height: 12),

          // Question card
          Container(
            width: double.infinity,
            decoration: glassCard(),
            padding: const EdgeInsets.all(16),
            child: Text(
              q.type == QuizType.termToMeaning
                  ? 'What does “${q.prompt}” mean?'
                  : 'Which slang matches:\n“${q.prompt}”',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Options (colored when answered)
          ...q.options.map((opt) {
            final selected = state.selected;

            Color bgColor;
            Color borderColor = Colors.white.withOpacity(0.15);
            Color textColor = Colors.white;

            if (selected == null) {
              bgColor = Colors.white.withOpacity(0.06);
            } else {
              if (opt == correct) {
                bgColor = Colors.green.withOpacity(0.28);
                borderColor = Colors.greenAccent.withOpacity(0.8);
                textColor = Colors.white;
              } else if (opt == selected && opt != correct) {
                bgColor = Colors.red.withOpacity(0.28);
                borderColor = Colors.redAccent.withOpacity(0.8);
                textColor = Colors.white;
              } else {
                bgColor = Colors.white.withOpacity(0.08);
                textColor = Colors.white70;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: selected == null
                    ? () {
                        ctrl.select(opt);
                        // ✅ Award XP for correct answer (next step)
                        if (opt == correct) {
                          ref.read(streakFBProvider.notifier).trackQuizXP();
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: bgColor,
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (selected != null && opt == correct)
                        const Icon(Icons.check_circle, color: Colors.greenAccent),
                      if (selected != null && opt == selected && opt != correct)
                        const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Next / Finish
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isAnswered ? ctrl.next : null,
                  child: Text(
                    (state.index == state.questions.length - 1)
                        ? 'Finish'
                        : 'Next',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Finished screen with shareable result card + confetti + QR code
class _Finished extends ConsumerStatefulWidget {
  final int score;
  final int total;
  final VoidCallback onRetry;

  const _Finished({
    required this.score,
    required this.total,
    required this.onRetry,
  });

  @override
  ConsumerState<_Finished> createState() => _FinishedState();
}

class _FinishedState extends ConsumerState<_Finished> {
  final ScreenshotController _shot = ScreenshotController();
  late final ConfettiController _confetti;

  static const String _appUrl =
      'https://play.google.com/store/apps/details?id=com.example.genz_dictionary';

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _quip {
    final pct = widget.score / widget.total;
    if (pct >= 0.9) return 'Certified rizz scholar 😎';
    if (pct >= 0.7) return 'Big brain energy 🧠';
    if (pct >= 0.5) return 'Not bad — keep grinding 💪';
    return 'A lil delulu… but learning! 🤓';
  }

  Future<void> _onShareQuizResult() async {
    _confetti.play();
    final img = await _shot.capture(pixelRatio: ui.window.devicePixelRatio);
    if (img == null) return;

    final file = XFile.fromData(
      img,
      name: 'genz_quiz_${DateTime.now().millisecondsSinceEpoch}.png',
      mimeType: 'image/png',
    );

    final result = await Share.shareXFiles(
      [file],
      text:
          'I scored ${widget.score}/${widget.total} on the Gen Z Dictionary Quiz! $_appUrl',
    );

    if (result.status == ShareResultStatus.success) {
      // ✅ Only give XP if share was actually completed
      await ref.read(streakFBProvider.notifier).trackShared();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.6,
          ),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Screenshot(
                controller: _shot,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Slang Quiz Result',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.score} / ${widget.total}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _quip,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: QrImageView(
                              data: _appUrl,
                              size: 84,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Gen Z Dictionary',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _onShareQuizResult,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share result'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onRetry,
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to dictionary'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}