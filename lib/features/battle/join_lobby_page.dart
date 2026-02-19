import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'battle_lobby_service.dart';
import 'battle_lobby_model.dart';

class JoinLobbyPage extends ConsumerStatefulWidget {
  const JoinLobbyPage({super.key});

  @override
  ConsumerState<JoinLobbyPage> createState() => _JoinLobbyPageState();
}

class _JoinLobbyPageState extends ConsumerState<JoinLobbyPage> {
  final TextEditingController _codeController = TextEditingController();
  final BattleLobbyService _service = BattleLobbyService();

  StreamSubscription<BattleLobby?>? _sub;

  bool _joining = false;
  bool _navigated = false;

  String? _code; // normalized code we joined
  BattleLobby? _lobby;

  @override
  void dispose() {
    _sub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // ✅ safe uid (never crash)
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'demo_user_1';

  Future<void> _joinLobby() async {
    final code = _service.normalizeCode(_codeController.text);
    if (code.isEmpty) return;

    setState(() {
      _joining = true;
      _navigated = false;
      _code = code;
      _lobby = null;
    });

    final userId = _uid;

    try {
      // ✅ join lobby
      final success = await _service.joinLobby(code, userId);

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lobby not found or already joined.")),
        );
        setState(() => _joining = false);
        return;
      }

      // cancel old listener
      await _sub?.cancel();

      // ✅ watch realtime changes
      _sub = _service.watchLobby(code).listen((lobby) {
        if (!mounted || lobby == null) return;

        setState(() => _lobby = lobby);

        // ✅ Navigate ONLY ONCE when started
        if (!_navigated && lobby.status == 'started') {
          _navigated = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.goNamed(
              'battle_quiz',
              pathParameters: {'code': code},
              extra: userId, // ✅ always a non-null String now
            );
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Joined lobby $code successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error joining lobby: $e")),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;

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
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
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

            if (code != null)
              Text(
                'Lobby: $code',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),

            const SizedBox(height: 12),

            // 🔹 Live lobby info
            if (_lobby != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status: ${_lobby!.status}",
                      style: TextStyle(
                        color: _lobby!.status == 'started'
                            ? Colors.greenAccent
                            : (_lobby!.status == 'active'
                                ? Colors.amberAccent
                                : Colors.white70),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("Host: ${_lobby!.hostId}",
                        style: const TextStyle(color: Colors.white70)),
                    if (_lobby!.guestId != null)
                      Text("Guest: ${_lobby!.guestId}",
                          style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    if (_lobby!.status != 'started')
                      Text(
                        'Waiting for host to start…',
                        style: TextStyle(color: Colors.white.withOpacity(0.65)),
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