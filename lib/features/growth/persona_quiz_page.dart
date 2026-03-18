import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class PersonaQuizPage extends StatefulWidget {
  const PersonaQuizPage({super.key});

  @override
  State<PersonaQuizPage> createState() => _PersonaQuizPageState();
}

class _PersonaQuizPageState extends State<PersonaQuizPage> {
  int _index = 0;
  int _chaotic = 0;
  int _chill = 0;
  int _grind = 0;

  final _qs = const [
    'Friday night plan?',
    'Your texting style?',
    'Pick a vibe',
  ];

  void _pick(String key) {
    if (key == 'chaotic') _chaotic++;
    if (key == 'chill') _chill++;
    if (key == 'grind') _grind++;
    if (_index < _qs.length - 1) {
      setState(() => _index++);
    } else {
      setState(() {});
    }
  }

  String get _result {
    if (_chaotic >= _chill && _chaotic >= _grind) return 'Chaos Creator';
    if (_grind >= _chill) return 'Main Character Grinder';
    return 'Calm Aesthetic Legend';
  }

  @override
  Widget build(BuildContext context) {
    final finished = (_chaotic + _chill + _grind) >= _qs.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Persona Quiz')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: finished
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _result,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Share.share(
                          'I got "$_result" in Gen Z Persona Quiz.',
                        ),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _qs[_index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _opt('chaotic', 'Unhinged with friends'),
                      _opt('chill', 'Lowkey and cozy'),
                      _opt('grind', 'Build and improve'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _opt(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _pick(key),
          child: Text(label),
        ),
      ),
    );
  }
}
