// lib/features/battle/create_lobby_page.dart

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
  bool _starting = false;

  String? _code;
  BattleLobby? _lobby;

  bool _navigated = false;

  // Host user id for emulator testing
  static const String _hostUserId = FirebaseAuth.instance.currentUser!.uid

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
      _navigated = false;
    });

    // Allow UI to paint spinner
    await Future.delayed(const Duration(milliseconds: 120));

    try {
      // ✅ Load slang list from your provider (local JSON)
      final slangList = await ref.read(slangListProvider.future);
      if (slangList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No slang data found.')),
          );
        }
        return;
      }

      // ✅ Choose 10 random terms as questions
      final terms = slangList.map((e) => e.term).toList()..shuffle();
      final questions = terms.take(10).toList();

      // ✅ Create lobby in Firestore
      final code = await _service.createLobby(
        userId: _hostUserId,
        questions: questions,
      );

      setState(() => _code = code);

      // ✅ Listen for lobby updates (guest joining, status changes, etc.)
      await _sub?.cancel();
      _sub = _service.watchLobby(code).listen((lobby) {
        if (!mounted || lobby == null) return;

        setState(() => _lobby = lobby);

        // ✅ Navigate both players when status becomes started
        if (!_navigated && lobby.status == 'started') {
          _navigated = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.goNamed(
              'battle_quiz',
              pathParameters: {'code': code},
              extra: _hostUserId, // ✅ userId passed via extra (Option A)
            );
          });
        }
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

  Future<void> _startBattle() async {
    final code = _code;
    final lobby = _lobby;
    if (code == null || lobby == null) return;

    // Only start if ready
    if (lobby.status != 'active' || lobby.guestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lobby not ready. Waiting for guest.')),
      );
      return;
    }

    setState(() => _starting = true);

    try {
      // ✅ THIS IS THE PART YOU ASKED ABOUT — IT BELONGS HERE
      // 1) Load slang list
      final slangList = await ref.read(slangListProvider.future);

      // 2) Build term -> meaning map
      final termToMeaning = {
        for (final s in slangList) s.term: s.meaning,
      };

      // 3) Call startBattle with frozen options generation inside service
      await _service.startBattle(
        rawCode: code,
        termToMeaning: termToMeaning,
      );

      // No manual navigation here; watcher above will navigate when status changes to started
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting battle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final lobby = _lobby;

    final friendJoined = lobby?.guestId != null;
    final readyToStart = lobby?.status == 'active' && friendJoined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Battle Lobby'),
        actions: [
          if (code != null)
            IconButton(
              tooltip: 'Create new lobby',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _creating ? null : _createLobby,
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _creating
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Creating your lobby...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                )
              : (code == null)
                  ? ElevatedButton.icon(
                      onPressed: _createLobby,
                      icon: const Icon(Icons.sports_kabaddi_rounded),
                      label: const Text('Create Lobby'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(200, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lobby Code: $code',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: code,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status / Friend joined label
                        if (friendJoined)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              '✅ Friend joined: ${lobby?.guestId}',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'Waiting for a friend to join…',
                            style: TextStyle(color: Colors.white70),
                          ),

                        const SizedBox(height: 18),

                        // Start button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                readyToStart && !_starting ? _startBattle : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _starting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Start Battle',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Back',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}