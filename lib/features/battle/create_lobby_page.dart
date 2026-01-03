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
  bool _navigated = false;

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
      _starting = false;
      _navigated = false;
      _code = null;
      _lobby = null;
    });

    await Future.delayed(const Duration(milliseconds: 150)); // allow UI update

    try {
      const userId = "demo_user_1"; // TODO replace with FirebaseAuth uid later

      // ✅ Load slang list
      final slangList = await ref.read(slangListProvider.future);
      if (slangList.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No slang data found.')),
        );
        setState(() => _creating = false);
        return;
      }

      // ✅ Pick questions (10)
      final questions = slangList.map((e) => e.term).toList()..shuffle();
      final chosen = questions.take(10).toList();

      // ✅ Create lobby
      final code = await _service.createLobby(userId: userId, questions: chosen);

      if (!mounted) return;
      setState(() => _code = code);

      // cancel old listener
      await _sub?.cancel();

      // ✅ Watch lobby updates
      _sub = _service.watchLobby(code).listen((lobby) {
        if (!mounted || lobby == null) return;

        setState(() => _lobby = lobby);

        // ✅ Phase 2: navigate ONLY ONCE when started
        if (!_navigated && lobby.status == 'started') {
          _navigated = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.goNamed(
              'battle_quiz',
              pathParameters: {'code': code},
              extra: userId, // ✅ pass host userId via extra
            );
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating lobby: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _startBattle() async {
    final code = _code;
    final lobby = _lobby;
    if (code == null || lobby == null) return;

    // safety checks
    if (lobby.guestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No guest joined yet.')),
      );
      return;
    }
    if (_starting) return;

    setState(() => _starting = true);

    try {
      const userId = "demo_user_1";
      await _service.startBattle(code);

      // navigation happens from stream when status becomes started
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting battle: $e')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final lobby = _lobby;

    final guestJoined = lobby?.guestId != null;
    final canStart = guestJoined && lobby?.status == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Battle Lobby'),
        actions: [
          if (code != null)
            IconButton(
              tooltip: 'Create new lobby',
              onPressed: _creating ? null : _createLobby,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
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
                        QrImageView(
                          data: code,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 18),

                        if (guestJoined)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.greenAccent),
                            ),
                            child: Text(
                              '✅ Friend joined: ${lobby!.guestId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.greenAccent,
                              ),
                            ),
                          )
                        else
                          const Text('Waiting for a friend to join...'),

                        const SizedBox(height: 18),

                        // ✅ Start Battle button (Phase 2)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canStart ? _startBattle : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _starting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    guestJoined
                                        ? 'Start Battle'
                                        : 'Start Battle (need guest)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 8),

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