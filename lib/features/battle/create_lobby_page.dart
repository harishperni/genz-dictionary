// lib/features/battle/create_lobby_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:genz_dictionary/features/slang/app/slang_providers.dart';
import 'battle_lobby_service.dart';
import 'battle_lobby_model.dart';

class CreateLobbyPage extends ConsumerStatefulWidget {
  const CreateLobbyPage({super.key});

  @override
  ConsumerState<CreateLobbyPage> createState() => _CreateLobbyPageState();
}

class _CreateLobbyPageState extends ConsumerState<CreateLobbyPage> {
  final BattleLobbyService _service = BattleLobbyService();
  StreamSubscription<BattleLobby?>? _sub;

  bool _creating = false;
  bool _starting = false;

  String? _code;
  BattleLobby? _lobby;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _createLobby() async {
    setState(() => _creating = true);
    await Future.delayed(const Duration(milliseconds: 120));

    try {
      // load slang list once
      final slangList = await ref.read(slangListProvider.future);
      if (slangList.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No slang data found.')),
        );
        return;
      }

      // choose 10 terms
      final terms = slangList.map((e) => e.term).toList()..shuffle();
      final questions = terms.take(10).toList();

      final code = await _service.createLobby(userId: _uid, questions: questions);
      setState(() => _code = code);

      await _sub?.cancel();
      _sub = _service.watchLobby(code).listen((lobby) {
        if (!mounted || lobby == null) return;
        setState(() => _lobby = lobby);

        // ✅ Navigate when started
        // Timer sync is handled in BattleQuizPage using lobby.battleStartsAt/questionStartedAt
        if (lobby.status == 'started') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.goNamed(
              'battle_quiz',
              pathParameters: {'code': code},
              extra: _uid,
            );
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error creating lobby: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _startBattle() async {
    final code = _code;
    if (code == null) return;

    setState(() => _starting = true);

    try {
      // build term -> meaning map from your local data
      final slangList = await ref.read(slangListProvider.future);
      final termToMeaning = {for (final s in slangList) s.term: s.meaning};

      // ✅ IMPORTANT:
      // startBattle() should write battleStartsAt + questionStartedAt using SERVER-SYNCED time.
      // (You’ll update BattleLobbyService.startBattle accordingly.)
      await _service.startBattle(
        rawCode: code,
        termToMeaning: termToMeaning,
        timerSeconds: 15,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Start failed: $e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final lobby = _lobby;

    final isHost = lobby != null && lobby.hostId == _uid;
    final canStart = lobby != null && lobby.status == 'active' && isHost;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Battle Lobby')),
      body: Center(
        child: _creating
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Creating your lobby...'),
                ],
              )
            : code == null
                ? ElevatedButton.icon(
                    onPressed: _createLobby,
                    icon: const Icon(Icons.sports_kabaddi_rounded),
                    label: const Text('Create Lobby'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lobby Code: $code',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: code,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),

                        if (lobby == null) ...[
                          const Text('Loading lobby…'),
                        ] else ...[
                          Text('Status: ${lobby.status}'),
                          const SizedBox(height: 10),
                          Text('Host: ${lobby.hostId}'),
                          Text('Guest: ${lobby.guestId ?? "—"}'),
                        ],

                        const SizedBox(height: 22),

                        if (canStart)
                          _starting
                              ? const CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  onPressed: _startBattle,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Start Battle'),
                                )
                        else ...[
                          const Text('Waiting for a friend to join...'),
                          const SizedBox(height: 12),
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}