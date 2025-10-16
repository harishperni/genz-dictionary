import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:genz_dictionary/features/slang/app/slang_providers.dart';
import '../battle/battle_lobby_service.dart';
import '../battle/battle_lobby_model.dart';

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
    setState(() => _creating = true);
    await Future.delayed(const Duration(milliseconds: 150)); // allow UI update

    try {
      const userId = "demo_user_1"; // TODO: replace with logged-in user later

      // ✅ Load slang list efficiently (limited)
      final slangList = await ref.read(slangListProvider.future);
      if (slangList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No slang data found.')),
          );
        }
        return;
      }

      // Take 10 random questions
      final questions =
          slangList.take(10).map((e) => e.term).toList()..shuffle();

      // ✅ Create lobby
      final code =
          await _service.createLobby(userId: userId, questions: questions);
      setState(() => _code = code);

      // Cancel old listener if exists
      await _sub?.cancel();

      // ✅ Watch opponent join
      _sub = _service.watchLobby(code).listen((lobby) {
        if (!mounted || lobby == null) return;
        setState(() => _lobby = lobby);

        // When guest joins
        if (lobby.guestId != null && lobby.status == 'active') {
          context.pushNamed('battle_quiz', pathParameters: {'code': code});
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

  @override
  Widget build(BuildContext context) {
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
            : _code == null
                ? ElevatedButton.icon(
                    onPressed: _createLobby,
                    icon: const Icon(Icons.sports_kabaddi_rounded),
                    label: const Text('Create Lobby'),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lobby Code: $_code',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _code!,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      const Text('Waiting for a friend to join...'),
                      const SizedBox(height: 12),
                      const CircularProgressIndicator(),
                    ],
                  ),
      ),
    );
  }
}