import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slang/app/slang_providers.dart';
import '../slang/domain/slang_entry.dart';
import 'battle_lobby_model.dart';
import 'battle_lobby_service.dart';
import 'battle_history_service.dart';

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
  final Map<String, Future<String>> _nameCache = {};

  bool _submitted = false;

  Duration _serverOffset = Duration.zero;
  bool _offsetReady = false;

  Timer? _uiTick;
  int _lastIndexSeen = -1;
  bool _forcedLockThisIndex = false;
  bool _resultPersistTriggered = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final off = await _service.getServerTimeOffset();
      if (!mounted) return;
      setState(() {
        _serverOffset = off;
        _offsetReady = true;
      });
    });

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
    final total = lobby.timerSeconds; // 15
    if (startedAt == null) return total;

    final elapsedMs = _serverNow().difference(startedAt).inMilliseconds;
    final remainingMs = (total * 1000) - elapsedMs;
    final rem = (remainingMs / 1000).ceil();
    return rem.clamp(0, total);
  }

  int _secondsUntil(DateTime target) {
    final diffMs = target.difference(_serverNow()).inMilliseconds;
    final s = (diffMs / 1000).ceil();
    return s < 0 ? 0 : s;
  }

  Future<String> _displayName(String uid) {
    return _nameCache.putIfAbsent(uid, () async {
      if (uid.trim().isEmpty) return '—';
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final raw =
          (data['displayId'] ?? data['username'] ?? '').toString().trim();
      if (raw.isNotEmpty) return raw;
      if (uid.length <= 8) return uid;
      return '${uid.substring(0, 4)}...${uid.substring(uid.length - 2)}';
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

    if (!_offsetReady) {
      return const Center(
        child: Text('Syncing time…', style: TextStyle(color: Colors.white70)),
      );
    }

    // ✅ Finished screen with winner + share/copy
    if (lobby.status == 'finished') {
      if (!_resultPersistTriggered) {
        _resultPersistTriggered = true;
        Future.microtask(() async {
          await BattleHistoryService().recordBattleIfNeeded(
            lobbyCode: widget.code,
          );
        });
      }

      final hostScore = lobby.scores[lobby.hostId] ?? 0;
      final guestScore =
          (lobby.guestId == null) ? 0 : (lobby.scores[lobby.guestId!] ?? 0);

      final isHostMe = lobby.hostId == widget.userId;
      final myScore = isHostMe ? hostScore : guestScore;
      final oppScore = isHostMe ? guestScore : hostScore;

      String resultText;
      if (myScore > oppScore) {
        resultText = 'You won 🏆';
      } else if (myScore < oppScore) {
        resultText = 'You lost 😭';
      } else {
        resultText = 'It’s a tie 🤝';
      }

      final shareText =
          'GenZ Dictionary Battle Result!\nCode: ${widget.code}\nHost: $hostScore  Guest: $guestScore';

      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resultText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Host: $hostScore   •   Guest: $guestScore',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              FutureBuilder<String>(
                future: _displayName(isHostMe ? (lobby.guestId ?? '') : lobby.hostId),
                builder: (context, snap) => Text(
                  'Opponent: ${snap.data ?? '...'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ✅ Share / Copy
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied result to clipboard ✅')),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share / Copy Result'),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ Rematch (Host only)
              if (isHostMe)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // 1) pull slang list to pick new questions
                        final slangs = await ref.read(slangListProvider.future);
                        final terms = slangs.map((e) => e.term).toList()..shuffle();
                        final newQuestions = terms.take(10).toList();

                        // 2) reset lobby to active with new questions
                        await _service.prepareRematch(
                          rawCode: widget.code,
                          hostUserId: widget.userId,
                          newQuestions: newQuestions,
                        );

                        // 3) start battle again (same guest, same code)
                        final termToMeaning = {for (final s in slangs) s.term: s.meaning};

                        await _service.startBattle(
                          rawCode: widget.code,
                          termToMeaning: termToMeaning,
                          timerSeconds: 15,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Rematch failed: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Rematch (Play Again)'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Waiting for host to start a rematch…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // ✅ Back
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Start gate (both phones wait)
    final startAt = lobby.battleStartsAt;
    if (startAt != null && _serverNow().isBefore(startAt)) {
      final secs = _secondsUntil(startAt);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_kabaddi_rounded,
              color: Colors.white, size: 44),
          const SizedBox(height: 14),
          const Text('Get ready…',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('Starting in ${secs}s',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.80),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          Text('Both players will start together.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700)),
        ],
      );
    }

    final idx = lobby.currentIndex;

    if (idx != _lastIndexSeen) {
      _lastIndexSeen = idx;
      _resetForIndex(idx);
    }

    if (idx < 0 || idx >= lobby.questions.length) {
      return const Center(
        child: Text('Invalid question index.',
            style: TextStyle(color: Colors.white)),
      );
    }

    final term = lobby.questions[idx];
    final locked = lobby.locked['$idx'] == true;

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

    final reveal = myAnswer != null || locked;

    final hostScore = lobby.scores[lobby.hostId] ?? 0;
    final guestScore =
        (lobby.guestId == null) ? 0 : (lobby.scores[lobby.guestId!] ?? 0);

    final remaining = _remainingForLobby(lobby);

    // Time up → lock once
    if (remaining <= 0 && !locked && !_forcedLockThisIndex) {
      _forcedLockThisIndex = true;
      Future.microtask(() async {
        await _service.forceLockIfTimeUp(rawCode: widget.code, index: idx);
      });
    }

    // ✅ If locked, host advances AFTER delay (both will see red/green during delay)
    if (locked && lobby.hostId == widget.userId) {
      Future.microtask(() async {
        await _service.advanceIfReady(
          rawCode: widget.code,
          hostUserId: widget.userId,
          serverOffset: _serverOffset,
          revealDelayMs: 2200,
        );
      });
    }

    return ref.watch(slangListProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (slangs) {
        final entry = _findEntry(slangs, term);
        final correctAnswer = entry.meaning.trim();
        final options = lobby.options['$idx'];

        if (options == null || options.length < 4) {
          return const Center(child: CircularProgressIndicator());
        }

        Widget statusBanner;
        if (locked) {
          statusBanner = _banner(
            text: bothAnswered ? 'Locked 🔒 both answered' : 'Locked 🔒 time up',
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
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<String>(
                    future: _displayName(lobby.hostId),
                    builder: (context, snap) => Text(
                      'Host: ${snap.data ?? '...'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<String>(
                    future: _displayName(lobby.guestId ?? ''),
                    builder: (context, snap) => Text(
                      'Guest: ${snap.data ?? '—'}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                reveal: reveal,
                locked: locked,
                onTap: (locked || _submitted || remaining <= 0)
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
        Text('Question ${idx + 1} / $total',
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text('What does “${entry.term}” mean?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
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

    Color borderColor = Colors.white.withValues(alpha: 0.14);
    Color fillColor = Colors.white.withValues(alpha: 0.06);

    if (state == _OptionVisualState.correct) {
      borderColor = Colors.greenAccent.withValues(alpha: 0.9);
      fillColor = Colors.greenAccent.withValues(alpha: 0.18);
    } else if (state == _OptionVisualState.wrong) {
      borderColor = Colors.redAccent.withValues(alpha: 0.9);
      fillColor = Colors.redAccent.withValues(alpha: 0.16);
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
              child: Text(opt,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
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
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String text, required Color tone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
