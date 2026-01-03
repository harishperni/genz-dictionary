// lib/features/battle/battle_quiz_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slang/app/slang_providers.dart';
import '../slang/domain/slang_entry.dart';
import 'battle_lobby_model.dart';
import 'battle_lobby_service.dart';

class BattleQuizPage extends ConsumerStatefulWidget {
  final String code;
  final String userId;

  const BattleQuizPage({
    super.key,
    required this.code,
    required this.userId,
  });

  @override
  ConsumerState<BattleQuizPage> createState() => _BattleQuizPageState();
}

class _BattleQuizPageState extends ConsumerState<BattleQuizPage> {
  final _service = BattleLobbyService();

  // local UI state
  String? _selected;
  bool? _wasCorrect;
  bool _submitting = false;

  // reset UI when question index changes
  int _lastIdx = -1;

  @override
  Widget build(BuildContext context) {
    final lobbyStream = _service.watchLobby(widget.code);

    return StreamBuilder<BattleLobby?>(
      stream: lobbyStream,
      builder: (context, snap) {
        final lobby = snap.data;

        return Scaffold(
          appBar: AppBar(title: Text('Battle Quiz • ${widget.code}')),
          body: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _body(context, lobby),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, BattleLobby? lobby) {
    if (lobby == null) {
      return const Center(
        child: Text('Lobby not found.', style: TextStyle(color: Colors.white)),
      );
    }

    if (lobby.status != 'started' && lobby.status != 'finished') {
      return const Center(
        child: Text('Waiting for host to start…',
            style: TextStyle(color: Colors.white)),
      );
    }

    if (lobby.status == 'finished') {
      final hostScore = lobby.scores[lobby.hostId] ?? 0;
      final guestScore = lobby.guestId == null ? 0 : (lobby.scores[lobby.guestId!] ?? 0);
      final winner = hostScore == guestScore
          ? 'Tie!'
          : (hostScore > guestScore ? 'Host wins!' : 'Guest wins!');

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Battle finished!',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Host: $hostScore   Guest: $guestScore',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(winner, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }

    final idx = lobby.currentIndex;
    final questions = lobby.questions;

    // reset UI when question changes
    if (idx != _lastIdx) {
      _lastIdx = idx;
      _selected = null;
      _wasCorrect = null;
      _submitting = false;
    }

    if (idx < 0 || idx >= questions.length) {
      return const Center(
        child: Text('Invalid question index.',
            style: TextStyle(color: Colors.white)),
      );
    }

    final term = questions[idx];
    final isHost = lobby.hostId == widget.userId;

    // who already answered
    final answersForIndex = Map<String, dynamic>.from(
      (lobby.answers['$idx'] as Map?) ?? {},
    );
    final iAnswered = answersForIndex.containsKey(widget.userId);

    // if answered from Firestore, sync local UI to avoid “losing selection”
    if (iAnswered && _selected == null) {
      final my = Map<String, dynamic>.from(answersForIndex[widget.userId] as Map);
      _selected = (my['selected'] ?? '').toString();
      _wasCorrect = (my['correct'] == true);
    }

    final bothAnswered = lobby.guestId != null &&
        answersForIndex.containsKey(lobby.hostId) &&
        answersForIndex.containsKey(lobby.guestId);

    final locked = (lobby.locked['$idx'] == true);

    final listAsync = ref.watch(slangListProvider);

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (slangs) {
        final entry = slangs.firstWhere(
          (s) => s.term.toLowerCase() == term.toLowerCase(),
          orElse: () => slangs.first,
        );

        // ✅ get frozen options from Firestore
        List<String>? options = lobby.options['$idx'];

        // if missing, host generates ONCE and writes
        if (options == null || options.length != 4) {
          if (isHost) {
            final generated = _buildOptions(entry, slangs);
            _service.setOptionsIfMissing(
              rawCode: widget.code,
              index: idx,
              options: generated,
            );
          }
          // until firestore returns, show small loading
          return const Center(
            child: Text('Preparing question…', style: TextStyle(color: Colors.white70)),
          );
        }

        final correctAnswer = entry.meaning.trim();
        final scores = lobby.scores;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${idx + 1} / ${questions.length}',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            _glassCard(
              child: Text(
                'What does “${entry.term}” mean?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ),

            const SizedBox(height: 14),

            // ✅ Options
            for (final opt in options) ...[
              _OptionTile(
                text: opt,
                selected: _selected == opt,
                correct: (_selected == opt && _wasCorrect == true),
                wrong: (_selected == opt && _wasCorrect == false),
                disabled: locked || iAnswered || _submitting,
                onTap: () async {
                  if (locked || iAnswered || _submitting) return;

                  setState(() {
                    _selected = opt;
                    _wasCorrect = (opt.trim() == correctAnswer);
                    _submitting = true;
                  });

                  try {
                    await _service.submitAnswer(
                      rawCode: widget.code,
                      userId: widget.userId,
                      index: idx,
                      selected: opt,
                      correct: (opt.trim() == correctAnswer),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _submitting = false);
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 8),

            // ✅ Feedback
            if (_selected != null)
              Text(
                _wasCorrect == true ? '✅ Correct!' : '❌ Wrong',
                style: TextStyle(
                  color: _wasCorrect == true ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),

            const SizedBox(height: 10),

            // ✅ Scores
            Row(
              children: [
                Text('Host: ${scores[lobby.hostId] ?? 0}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 14),
                Text('Guest: ${lobby.guestId == null ? 0 : (scores[lobby.guestId!] ?? 0)}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),

            const Spacer(),

            // ✅ Next button (host controls)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isHost
                    ? () async {
                        // Optional: require both answered before host can advance
                        if (!bothAnswered) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Waiting for both players to answer…')),
                          );
                          return;
                        }
                        await _service.advanceQuestion(widget.code);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(isHost ? 'Next (Host)' : 'Waiting for host…'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ Build 4 options: 1 correct + 3 distractors
  List<String> _buildOptions(SlangEntry correct, List<SlangEntry> all) {
    final rand = Random();
    final correctMeaning = correct.meaning.trim();

    // pool of other meanings
    final pool = all
        .where((e) => e.term.toLowerCase() != correct.term.toLowerCase())
        .map((e) => e.meaning.trim())
        .where((m) => m.isNotEmpty && m.toLowerCase() != correctMeaning.toLowerCase())
        .toList();

    pool.shuffle(rand);

    final distractors = pool.take(3).toList();
    final opts = <String>[correctMeaning, ...distractors];

    // shuffle ONCE here (host will freeze to firestore)
    opts.shuffle(rand);

    // ensure exactly 4 (fallback if dataset small)
    while (opts.length < 4) {
      opts.add(correctMeaning);
    }
    return opts.take(4).toList();
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool disabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white.withOpacity(0.12);
    Color bg = Colors.white.withOpacity(0.06);

    if (correct) {
      border = Colors.greenAccent;
      bg = Colors.greenAccent.withOpacity(0.18);
    } else if (wrong) {
      border = Colors.redAccent;
      bg = Colors.redAccent.withOpacity(0.16);
    } else if (selected) {
      border = Colors.white.withOpacity(0.35);
      bg = Colors.white.withOpacity(0.10);
    }

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.2,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}