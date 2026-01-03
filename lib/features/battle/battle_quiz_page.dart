import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slang/app/slang_providers.dart';
import 'battle_lobby_service.dart';
import 'battle_lobby_model.dart';

class BattleQuizPage extends ConsumerWidget {
  final String code;
  final String userId;

  const BattleQuizPage({
    super.key,
    required this.code,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyStream = BattleLobbyService().watchLobby(code);

    return StreamBuilder<BattleLobby?>(
      stream: lobbyStream,
      builder: (context, snapshot) {
        final lobby = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: Text('Battle Quiz • $code')),
          body: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _body(context, ref, lobby),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, BattleLobby? lobby) {
    if (lobby == null) {
      return const Center(
        child: Text('Lobby not found',
            style: TextStyle(color: Colors.white)),
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
        child: Text('Battle finished!',
            style: TextStyle(color: Colors.white)),
      );
    }

    final idx = lobby.currentIndex;
    final questions = lobby.questions;

    if (idx < 0 || idx >= questions.length) {
      return const Center(
        child: Text('Invalid question index',
            style: TextStyle(color: Colors.white)),
      );
    }

    final term = questions[idx];
    final options = lobby.options['$idx'] ?? [];
    final locked = lobby.locked['$idx'] == true;
    final answersForIndex =
        Map<String, dynamic>.from(lobby.answers['$idx'] ?? {});
    final alreadyAnswered = answersForIndex.containsKey(userId);

    final isHost = lobby.hostId == userId;

    final slangAsync = ref.watch(slangListProvider);

    return slangAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: Colors.white)),
      ),
      data: (slangs) {
        final entry = slangs.firstWhere(
          (s) => s.term.toLowerCase() == term.toLowerCase(),
          orElse: () => slangs.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${idx + 1} / ${questions.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            _card(
              'What does “${entry.term}” mean?',
              bold: true,
            ),

            const SizedBox(height: 12),

            ...options.map((opt) {
              final isSelected =
                  answersForIndex[userId]?['selected'] == opt;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  onPressed: locked || alreadyAnswered
                      ? null
                      : () async {
                          final correct = opt == entry.meaning;
                          await BattleLobbyService().submitAnswer(
                            rawCode: code,
                            userId: userId,
                            index: idx,
                            selected: opt,
                            correct: correct,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? (answersForIndex[userId]?['correct'] == true
                            ? Colors.green
                            : Colors.red)
                        : Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(opt),
                ),
              );
            }).toList(),

            const Spacer(),

            if (isHost)
              ElevatedButton.icon(
                onPressed: () async {
                  await BattleLobbyService().advanceQuestion(code);
                },
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Next (Host)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _card(String text, {bool bold = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}