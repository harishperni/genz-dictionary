import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BattleMenuPage extends StatelessWidget {
  const BattleMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[900],
      appBar: AppBar(
        title: const Text('1v1 Battle'),
        backgroundColor: Colors.deepPurple[800],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Lobby', style: TextStyle(fontSize: 18)),
              onPressed: () => context.pushNamed('createLobby'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                side: const BorderSide(color: Colors.white70),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Join Lobby', style: TextStyle(fontSize: 18)),
              onPressed: () => context.pushNamed('joinLobby'),
            ),
          ],
        ),
      ),
    );
  }
}