import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'battle_lobby_service.dart';
import 'battle_lobby_model.dart';

class JoinLobbyPage extends ConsumerStatefulWidget {
  const JoinLobbyPage({super.key});

  @override
  ConsumerState<JoinLobbyPage> createState() => _JoinLobbyPageState();
}

class _JoinLobbyPageState extends ConsumerState<JoinLobbyPage> {
  final TextEditingController _codeController = TextEditingController();
  final _service = BattleLobbyService();
  bool _joining = false;
  BattleLobby? _lobby;
  Stream<BattleLobby?>? _lobbyStream;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinLobby() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _joining = true);

    try {
      const userId = "demo_user_2"; // 🔧 Replace with Firebase Auth UID later
      final success = await _service.joinLobby(code, userId);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lobby not found or already active.")),
        );
        setState(() => _joining = false);
        return;
      }

      // Start listening for real-time updates
      _lobbyStream = _service.watchLobby(code);
      _lobbyStream!.listen((lobby) {
        if (!mounted || lobby == null) return;
        setState(() => _lobby = lobby);

        // Auto-navigate to battle quiz once active
        if (lobby.status == 'active') {
          context.pushNamed(
            'battle_quiz',
            pathParameters: {'code': code},
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Joined lobby #$code successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error joining lobby: $e")),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Battle Lobby')),
      body: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter Battle Code',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                letterSpacing: 4,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                hintText: 'e.g. F7KJ9A',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFF7C3AED), width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _joining
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Join Lobby'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _joinLobby,
                  ),
            const SizedBox(height: 40),

            // 🔹 Show live lobby info
            if (_lobby != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Text(
                      "Lobby: ${_lobby!.id}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Status: ${_lobby!.status}",
                      style: TextStyle(
                        color: _lobby!.status == 'active'
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Host: ${_lobby!.hostId}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_lobby!.guestId != null)
                      Text(
                        "Guest: ${_lobby!.guestId}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}