import 'dart:async';
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
  final BattleLobbyService _service = BattleLobbyService();
  bool _submitting = false;

  // prevent repeated auto-advance calls per index on this client
  final Set<int> _autoAdvanceRequested = {};

  @override
  Widget build(BuildContext context) {
    final stream = _service.watchLobby(widget.code);

    return StreamBuilder<BattleLobby?>(
      stream: stream,
      builder: (context, snap) {
        final lobby = snap.data;

        if (lobby == null) {
          return const Scaffold(
            body: Center(child: Text('Lobby not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Battle Quiz • ${lobby.id}'),
          ),
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

  Widget _body(BuildContext context, BattleLobby lobby) {
    if (lobby.status != 'started' && lobby.status != 'finished') {
      return const Center(
        child: Text(
          'Waiting for host to start…',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final isHost = lobby.hostId == widget.userId;

    // finished screen
    if (lobby.status == 'finished') {
      final hostScore = lobby.scores[lobby.hostId] ?? 0;
      final guestScore = (lobby.guestId != null) ? (lobby.scores[lobby.guestId!] ?? 0) : 0;

      String winner;
      if (hostScore > guestScore) winner = 'Host wins!';
      else if (guestScore > hostScore) winner = 'Guest wins!';
      else winner = 'It’s a tie!';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Battle finished!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Host: $hostScore   Guest: $guestScore', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(winner, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }

    final idx = lobby.currentIndex;
    final idxKey = '$idx';

    if (idx < 0 || idx >= lobby.questions.length) {
      return const Center(
        child: Text('Invalid question index.', style: TextStyle(color: Colors.white)),
      );
    }

    final term = lobby.questions[idx];

    // ✅ frozen options must exist for this index
    final options = lobby.options[idxKey];
    if (options == null || options.length < 2) {
      return const Center(
        child: Text(
          'Preparing question…',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final answersForIdx = (lobby.answers[idxKey] as Map?) ?? {};
    final myAnswer = answersForIdx[widget.userId] as Map?;
    final hostAnswer = (answersForIdx[lobby.hostId] as Map?);
    final guestAnswer = (lobby.guestId != null) ? (answersForIdx[lobby.guestId!] as Map?) : null;

    final iAnswered = myAnswer != null;
    final opponentAnswered = (isHost ? (guestAnswer != null) : (hostAnswer != null));
    final locked = lobby.locked[idxKey] == true;

    // ✅ auto-advance when locked
    if (locked && !_autoAdvanceRequested.contains(idx)) {
      _autoAdvanceRequested.add(idx);
      // small delay so users can see feedback
      Future.delayed(const Duration(milliseconds: 650), () {
        _service.tryAutoAdvanceIfLocked(widget.code);
      });
    }

    final hostScore = lobby.scores[lobby.hostId] ?? 0;
    final guestScore = (lobby.guestId != null) ? (lobby.scores[lobby.guestId!] ?? 0) : 0;

    final listAsync = ref.watch(slangListProvider);

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      data: (slangs) {
        final SlangEntry entry = slangs.firstWhere(
          (s) => s.term.toLowerCase() == term.toLowerCase(),
          orElse: () => slangs.first,
        );

        final correctAnswer = entry.meaning.trim();

        // banners
        final bannerText = locked
            ? 'Locked 🔒 both answered'
            : opponentAnswered
                ? 'Opponent answered ✅'
                : 'Waiting for opponent…';

        final bannerColor = locked
            ? Colors.green.withOpacity(0.18)
            : opponentAnswered
                ? Colors.blue.withOpacity(0.18)
                : Colors.orange.withOpacity(0.18);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // score row
            Row(
              children: [
                Expanded(
                  child: _scorePill(
                    icon: Icons.person,
                    label: 'Host: $hostScore',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _scorePill(
                    icon: Icons.person_outline,
                    label: 'Guest: $guestScore',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                bannerText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Question ${idx + 1} / ${lobby.questions.length}',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            // question card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                'What does “${entry.term}” mean?',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),

            const SizedBox(height: 12),

            // options
            for (final opt in options) ...[
              _optionTile(
                text: opt,
                enabled: !_submitting && !iAnswered && !locked,
                // ✅ highlight only after YOU answered
                state: _computeOptionState(
                  iAnswered: iAnswered,
                  mySelected: myAnswer?['selected']?.toString(),
                  myCorrect: myAnswer?['correct'] == true,
                  opt: opt,
                  correctAnswer: correctAnswer,
                ),
                onTap: () async {
                  if (_submitting || iAnswered || locked) return;

                  setState(() => _submitting = true);

                  final selected = opt.trim();
                  final isCorrect = selected == correctAnswer;

                  try {
                    await _service.submitAnswer(
                      rawCode: widget.code,
                      userId: widget.userId,
                      index: idx,
                      selected: selected,
                      correct: isCorrect,
                    );
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],

            const Spacer(),

            // ✅ only show correct meaning AFTER you answer (no spoiler)
            if (iAnswered) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  'Correct meaning: $correctAnswer',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ✅ remove manual next button (auto-advance). Keep a disabled button just for clarity.
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: const Color(0xFF7C3AED).withOpacity(0.25),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                locked ? 'Advancing…' : (isHost ? 'Auto-advance when both answer' : 'Waiting for opponent…'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _scorePill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  _OptionState _computeOptionState({
    required bool iAnswered,
    required String? mySelected,
    required bool myCorrect,
    required String opt,
    required String correctAnswer,
  }) {
    if (!iAnswered) return _OptionState.normal;

    final o = opt.trim();
    final sel = (mySelected ?? '').trim();

    if (o == sel && myCorrect) return _OptionState.correctSelected;
    if (o == sel && !myCorrect) return _OptionState.wrongSelected;

    // also show the correct one in green outline once answered
    if (o == correctAnswer.trim()) return _OptionState.correctReveal;

    return _OptionState.dim;
  }

  Widget _optionTile({
    required String text,
    required bool enabled,
    required _OptionState state,
    required VoidCallback onTap,
  }) {
    Color border = Colors.white.withOpacity(0.12);
    Color fill = Colors.white.withOpacity(0.06);

    switch (state) {
      case _OptionState.normal:
        break;
      case _OptionState.correctSelected:
        border = Colors.greenAccent.withOpacity(0.8);
        fill = Colors.greenAccent.withOpacity(0.15);
        break;
      case _OptionState.wrongSelected:
        border = Colors.redAccent.withOpacity(0.8);
        fill = Colors.redAccent.withOpacity(0.15);
        break;
      case _OptionState.correctReveal:
        border = Colors.greenAccent.withOpacity(0.5);
        fill = Colors.white.withOpacity(0.06);
        break;
      case _OptionState.dim:
        border = Colors.white.withOpacity(0.08);
        fill = Colors.white.withOpacity(0.03);
        break;
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(state == _OptionState.dim ? 0.55 : 1),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _OptionState {
  normal,
  correctSelected,
  wrongSelected,
  correctReveal,
  dim,
}