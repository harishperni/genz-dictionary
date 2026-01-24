import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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

  // local UI state per question
  bool _submitted = false;

  // server time sync
  Duration _serverOffset = Duration.zero;
  bool _offsetReady = false;

  // repaint ticker (UI only)
  Timer? _uiTick;

  int _lastIndexSeen = -1;
  bool _forcedLockThisIndex = false;

  @override
  void initState() {
    super.initState();

    // Get server offset once
    Future.microtask(() async {
      final off = await _service.getServerTimeOffset();
      if (!mounted) return;
      setState(() {
        _serverOffset = off;
        _offsetReady = true;
      });
    });

    // Frequent UI repaint for timer smoothness
    _uiTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    super.dispose();
  }

  DateTime _serverNow() => DateTime.now().add(_serverOffset);

  void _resetForIndex(int idx) {
    _submitted = false;
    _forcedLockThisIndex = false;
  }

  int _remainingForLobby(BattleLobby lobby) {
    final startedAt = lobby.questionStartedAt;
    final total = lobby.timerSeconds; // ✅ 15 comes from Firestore
    if (startedAt == null) return total;

    final elapsedMs = _serverNow().difference(startedAt).inMilliseconds;
    final remainingMs = (total * 1000) - elapsedMs;

    // ceil so it doesn’t drop early
    final rem = (remainingMs / 1000).ceil();
    return rem.clamp(0, total);
  }

  int _secondsUntil(DateTime target) {
    final diffMs = target.difference(_serverNow()).inMilliseconds;
    final s = (diffMs / 1000).ceil();
    return s < 0 ? 0 : s;
  }

  bool _isRevealWindow(BattleLobby lobby) {
    if (lobby.advanceAt == null) return false;
    final due = lobby.advanceAt!.add(Duration(milliseconds: lobby.advanceDelayMs));
    return _serverNow().isBefore(due);
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
        child: Text(
          'Waiting for host to start…',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_offsetReady) {
      return const Center(
        child: Text('Syncing time…', style: TextStyle(color: Colors.white70)),
      );
    }

    // ✅ Finished screen: Winner + Share
    if (lobby.status == 'finished') {
      final hostId = lobby.hostId;
      final guestId = lobby.guestId ?? '';

      final hostScore = lobby.scores[hostId] ?? 0;
      final guestScore = guestId.isEmpty ? 0 : (lobby.scores[guestId] ?? 0);

      final hostName = lobby.playerNames[hostId]?.trim().isNotEmpty == true
          ? lobby.playerNames[hostId]!.trim()
          : 'Host';

      final guestName = lobby.playerNames[guestId]?.trim().isNotEmpty == true
          ? lobby.playerNames[guestId]!.trim()
          : 'Guest';

      String winnerText;
      if (hostScore == guestScore) {
        winnerText = "It's a tie! 🤝";
      } else if (hostScore > guestScore) {
        winnerText = "$hostName won 🏆";
      } else {
        winnerText = "$guestName won 🏆";
      }

      final shareText =
          "Battle result: $hostName ($hostScore) vs $guestName ($guestScore). $winnerText";

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 56),
              const SizedBox(height: 14),
              Text(
                winnerText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "$hostName: $hostScore\n$guestName: $guestScore",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => Share.share(shareText),
                icon: const Icon(Icons.share_rounded),
                label: const Text("Share with friends"),
              ),
              const SizedBox(height: 10),
              Text(
                "Play again from Battle Menu",
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Phase 3 START GATE — both phones wait until shared battleStartsAt
    final startAt = lobby.battleStartsAt;
    if (startAt != null && _serverNow().isBefore(startAt)) {
      final secs = _secondsUntil(startAt);

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_kabaddi_rounded, color: Colors.white, size: 44),
          const SizedBox(height: 14),
          const Text(
            'Get ready…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Starting in ${secs}s',
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              value: (1 - (secs / 5)).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.10),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Both players will start together.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Normal in-game view
    final idx = lobby.currentIndex;

    if (idx != _lastIndexSeen) {
      _lastIndexSeen = idx;
      _resetForIndex(idx);
    }

    if (idx < 0 || idx >= lobby.questions.length) {
      return const Center(
        child: Text(
          'Invalid question index.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final term = lobby.questions[idx];

    // locked status
    final locked = lobby.locked['$idx'] == true;

    // answers for index
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

    final bothAnswered = lobby.hostId.isNotEmpty &&
        (lobby.guestId ?? '').isNotEmpty &&
        answersForIndex.containsKey(lobby.hostId) &&
        answersForIndex.containsKey(lobby.guestId);

    // reveal when locked OR I answered
    final reveal = myAnswer != null || locked;

    // scores
    final hostScore = lobby.scores[lobby.hostId] ?? 0;
    final guestScore =
        (lobby.guestId == null) ? 0 : (lobby.scores[lobby.guestId!] ?? 0);

    // remaining time (server-based)
    final remaining = _remainingForLobby(lobby);

    // If time is up and not locked yet, force lock ONCE
    if (remaining <= 0 && !locked && !_forcedLockThisIndex) {
      _forcedLockThisIndex = true;
      Future.microtask(() async {
        await _service.forceLockIfTimeUp(rawCode: widget.code, index: idx);
      });
    }

    // ✅ If locked and reveal window finished, advance (safe to call many times)
    if (locked && lobby.advanceAt != null && !_isRevealWindow(lobby)) {
      Future.microtask(() async {
        await _service.advanceIfDue(rawCode: widget.code);
      });
    }

    final isRevealing = locked && lobby.advanceAt != null && _isRevealWindow(lobby);

    return ref.watch(slangListProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (slangs) {
        final entry = _findEntry(slangs, term);
        final correctAnswer = entry.meaning.trim();

        // frozen options
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

        // status banner logic
        Widget statusBanner;
        if (locked) {
          statusBanner = _banner(
            text: bothAnswered
                ? (isRevealing ? 'Showing results…' : 'Locked 🔒')
                : (isRevealing ? 'Time up — showing results…' : 'Locked 🔒 time up'),
            icon: Icons.lock_rounded,
          );
        } else if (oppAnswered) {
          statusBanner = _banner(
            text: 'Opponent answered ✅',
            icon: Icons.check_circle_rounded,
          );
        } else {
          statusBanner = _banner(
            text: 'Waiting for opponent…',
            icon: Icons.person_outline,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topRow(hostScore: hostScore, guestScore: guestScore),
            const SizedBox(height: 12),
            Row(
              children: [
                _pill(
                  icon: Icons.timer_rounded,
                  text: '${remaining}s',
                  tone: remaining <= 3 ? Colors.redAccent : Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(child: statusBanner),
              ],
            ),
            const SizedBox(height: 14),
            _questionCard(idx: idx, total: lobby.questions.length, entry: entry),
            const SizedBox(height: 12),

            for (final opt in options) ...[
              const SizedBox(height: 10),
              _optionTile(
                opt: opt,
                correct: correctAnswer,
                myAnswer: myAnswer,
                reveal: reveal, // ✅ locked triggers reveal for both
                locked: locked,
                onTap: (locked || isRevealing || _submitted || remaining <= 0)
                    ? null
                    : () async {
                        setState(() {
                          _submitted = true;
                        });

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
          Text(text, style: TextStyle(color: tone, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

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
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

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