import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  String? _code;
  BattleLobby? _lobby;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _createLobby() async {
    setState(() {
      _creating = true;
      _code = null;
      _lobby = null;
    });

    await Future.delayed(const Duration(milliseconds: 150)); // allow UI update

    try {
      const userId = "demo_user_1"; // TODO: replace with Firebase Auth UID later

      final slangList = await ref.read(slangListProvider.future);
      if (slangList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No slang data found.')),
          );
        }
        return;
      }

      // Take 10 random terms (shuffle first, then take)
      final terms = slangList.map((e) => e.term).toList()..shuffle();
      final questions = terms.take(10).toList();

      final code = await _service.createLobby(userId: userId, questions: questions);

      // Save code first (so UI shows QR immediately)
      if (!mounted) return;
      setState(() => _code = code);

      // Cancel old listener if exists
      await _sub?.cancel();

      // Listen for lobby updates
      _sub = _service.watchLobby(code).listen((lobby) {
        if (!mounted || lobby == null) return;

        setState(() => _lobby = lobby);

        // OPTIONAL: If you later switch status to 'active' in Phase 2,
        // you can auto-navigate here.
        //
        // if (lobby.guestId != null && lobby.status == 'active') {
        //   context.pushNamed('battle_quiz', pathParameters: {'code': code});
        // }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating lobby: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final lobby = _lobby;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Battle Lobby'),
        actions: [
          if (code != null)
            IconButton(
              tooltip: 'Create new lobby',
              onPressed: _creating ? null : _createLobby,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lobby Code: $code',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // QR
                        Container(
                          padding: const EdgeInsets.all(10),
                          color: Colors.white,
                          child: QrImageView(
                            data: code,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ✅ LIVE STATUS (this is what fixes your issue)
                        if (lobby == null) ...[
                          const Text('Loading lobby status...'),
                          const SizedBox(height: 12),
                          const CircularProgressIndicator(),
                        ] else if (lobby.guestId == null) ...[
                          const Text('Waiting for a friend to join...'),
                          const SizedBox(height: 12),
                          const CircularProgressIndicator(),
                        ] else ...[
                          Text(
                            '✅ Friend joined: ${lobby.guestId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Phase 1 complete — lobby is ready.'),
                          const SizedBox(height: 16),

                          // Optional button for later (Phase 2 start)
                          FilledButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Next: implement Battle Quiz start (Phase 2).'),
                                ),
                              );
                            },
                            child: const Text('Start Battle (coming next)'),
                          ),
                        ],

                        const SizedBox(height: 18),

                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}