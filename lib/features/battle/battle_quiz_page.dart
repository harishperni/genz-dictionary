import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slang/app/slang_providers.dart';
import '../slang/domain/slang_entry.dart';
import 'battle_lobby_model.dart';
import 'battle_lobby_service.dart';

enum _OptionVisualState { neutral, correct, wrong }

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

  // Local UI state per question index
  String? _mySelected;
  bool _submitted = false;

  // Basic timer (Phase 3 will replace with synced server-based timer)
  Timer? _tick;
  int _remaining = 10;
  int _lastIndexSeen = -1;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _resetForIndex(int idx, int durationSec) {
    _mySelected = null;
    _submitted = false;

    _tick?.cancel();
    _remaining = durationSec;

    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining -= 1;
        if (_remaining <= 0) {
          _remaining = 0;
          t.cancel();
          // If time ends and user didn't answer, do nothing for now (phase 3 can auto-submit)
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final lobbyStream = _service.watchLobby(widget.code);

    return StreamBuilder<BattleLobby?>(
      stream: lobbyStream,
      builder: (context, snapshot) {
        final lobby = snapshot.data;

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
      return const Center(
        child:
            Text('Battle finished.', style: TextStyle(color: Colors.white)),
      );
    }

    final idx = lobby.currentIndex;
    final durationSec = lobby.durationSec;

    if (idx != _lastIndexSeen) {
      _lastIndexSeen = idx;
      _resetForIndex(idx, durationSec);
    }

    if (idx < 0 || idx >= lobby.questions.length) {
      return const Center(
        child: Text('Invalid question index.',
            style: TextStyle(color: Colors.white)),
      );
    }

    final term = lobby.questions[idx];

    // 🔒 Locked status from Firestore (both answered)
    final locked = lobby.locked['$idx'] == true;

    // Answers map for this index
    final answersForIndex =
        (lobby.answers['$idx'] as Map?)?.cast<String, dynamic>() ?? {};

    final myAnswerMap =
        (answersForIndex[widget.userId] as Map?)?.cast<String, dynamic>();
    final myAnswer = myAnswerMap?['selected']?.toString();

    final opponentId = (lobby.hostId == widget.userId)
        ? (lobby.guestId ?? '')
        : lobby.hostId;

    final oppAnswerMap =
        (answersForIndex[opponentId] as Map?)?.cast<String, dynamic>();
    final oppAnswered = oppAnswerMap != null;

    // Reveal when I answered OR locked
    final reveal = myAnswer != null || locked;

    // Scores
    final hostScore = lobby.scores[lobby.hostId] ?? 0;
    final guestScore =
        (lobby.guestId == null) ? 0 : (lobby.scores[lobby.guestId!] ?? 0);

    return ref.watch(slangListProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
          ),
          data: (slangs) {
            final entry = _findEntry(slangs, term);
            final correctAnswer = entry.meaning.trim();

            // ✅ MUST come from lobby.options to prevent jumbling
            final options = lobby.options['$idx'];

            if (options == null || options.length < 4) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topRow(hostScore: hostScore, guestScore: guestScore),
                  const SizedBox(height: 12),
                  _banner(text: 'Preparing options…', icon: Icons.hourglass_top),
                  const SizedBox(height: 16),
                  _questionCard(idx: idx, total: lobby.questions.length, entry: entry),
                  const Spacer(),
                  const Center(child: CircularProgressIndicator()),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Score row (restored old style)
                _topRow(hostScore: hostScore, guestScore: guestScore),

                const SizedBox(height: 12),

                // Timer + status
                Row(
                  children: [
                    _pill(
                      icon: Icons.timer_rounded,
                      text: '${_remaining}s',
                      tone: _remaining <= 3 ? Colors.redAccent : Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: locked
                          ? _banner(
                              text: 'Locked 🔒 both answered',
                              icon: Icons.lock_rounded,
                            )
                          : (oppAnswered
                              ? _banner(
                                  text: 'Opponent answered ✅',
                                  icon: Icons.check_circle_rounded,
                                )
                              : _banner(
                                  text: 'Waiting for opponent…',
                                  icon: Icons.person_outline,
                                )),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _questionCard(idx: idx, total: lobby.questions.length, entry: entry),

                const SizedBox(height: 12),

                // ✅ Options (restored highlight behavior)
                for (final opt in options) ...[
                  const SizedBox(height: 10),
                  _optionTile(
                    opt: opt,
                    correct: correctAnswer,
                    myAnswer: myAnswer,
                    reveal: reveal,
                    locked: locked,
                    onTap: (locked || _submitted)
                        ? null
                        : () async {
                            setState(() {
                              _mySelected = opt;
                              _submitted = true;
                            });

                            final isCorrect =
                                opt.trim() == correctAnswer.trim();

                            await _service.submitAnswer(
                              rawCode: widget.code,
                              userId: widget.userId,
                              index: idx,
                              selected: opt,
                              correctAnswer: correctAnswer,
                            );
                          },
                  ),
                ],

                const Spacer(),

                // No “correct answer” shown anywhere — this fixes your bug #1
              ],
            );
          },
        );
  }

  SlangEntry _findEntry(List<SlangEntry> slangs, String term) {
    final t = term.toLowerCase().trim();
    for (final s in slangs) {
      if (s.term.toLowerCase().trim() == t) return s;
    }
    return slangs.first;
  }

  Widget _topRow({required int hostScore, required int guestScore}) {
    return Row(
      children: [
        Expanded(child: _scoreCard(label: 'Host', score: hostScore)),
        const SizedBox(width: 10),
        Expanded(child: _scoreCard(label: 'Guest', score: guestScore)),
      ],
    );
  }

  Widget _questionCard({
    required int idx,
    required int total,
    required SlangEntry entry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${idx + 1} / $total',
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Text(
            'What does “${entry.term}” mean?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionTile({
    required String opt,
    required String correct,
    required String? myAnswer,
    required bool reveal,
    required bool locked,
    required VoidCallback? onTap,
  }) {
    final state = _optionState(
      opt: opt,
      correct: correct,
      myAnswer: myAnswer,
      reveal: reveal,
    );

    Color borderColor = Colors.white.withOpacity(0.14);
    Color fillColor = Colors.white.withOpacity(0.06);

    if (state == _OptionVisualState.correct) {
      borderColor = Colors.greenAccent.withOpacity(0.9);
      fillColor = Colors.greenAccent.withOpacity(0.18);
    } else if (state == _OptionVisualState.wrong) {
      borderColor = Colors.redAccent.withOpacity(0.9);
      fillColor = Colors.redAccent.withOpacity(0.16);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                opt,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (locked)
              const Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _banner({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String text, required Color tone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: tone, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ✅ Restored score UI (your old style)
  static Widget _scoreCard({required String label, required int score}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('$score',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
        ],
      ),
    );
  }

  // ✅ Restored option highlight logic
  _OptionVisualState _optionState({
    required String opt,
    required String correct,
    required String? myAnswer,
    required bool reveal,
  }) {
    if (!reveal) return _OptionVisualState.neutral;
    final isCorrect = opt.trim() == correct.trim();
    final isMine = myAnswer != null && opt.trim() == myAnswer.trim();
    if (isCorrect) return _OptionVisualState.correct;
    if (isMine && !isCorrect) return _OptionVisualState.wrong;
    return _OptionVisualState.neutral;
  }
}