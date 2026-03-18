import 'package:flutter/material.dart';

class AISlangCoachPage extends StatefulWidget {
  const AISlangCoachPage({super.key});

  @override
  State<AISlangCoachPage> createState() => _AISlangCoachPageState();
}

class _AISlangCoachPageState extends State<AISlangCoachPage> {
  final _input = TextEditingController();
  String _tone = 'funny';
  String _result = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _generate() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    String out = raw
        .replaceAll('really good', 'lowkey fire')
        .replaceAll('very', 'mad')
        .replaceAll('friend', 'bestie')
        .replaceAll('amazing', 'insane');

    if (_tone == 'savage') out = '$out. no cap.';
    if (_tone == 'wholesome') out = '$out :)';
    if (_tone == 'funny') out = '$out fr fr';

    setState(() => _result = out);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Slang Coach')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Type any sentence and get a Gen Z rewrite.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _input,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Type your sentence...',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _tone,
              items: const [
                DropdownMenuItem(value: 'funny', child: Text('Funny')),
                DropdownMenuItem(value: 'savage', child: Text('Savage')),
                DropdownMenuItem(value: 'wholesome', child: Text('Wholesome')),
              ],
              onChanged: (v) => setState(() => _tone = v ?? 'funny'),
              decoration: const InputDecoration(labelText: 'Tone'),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Rewrite'),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  _result,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
