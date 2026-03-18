import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../streak/streak_controller_firebase.dart';

class DailyMissionsPage extends ConsumerStatefulWidget {
  const DailyMissionsPage({super.key});

  @override
  ConsumerState<DailyMissionsPage> createState() => _DailyMissionsPageState();
}

class _DailyMissionsPageState extends ConsumerState<DailyMissionsPage> {
  bool _m1 = false;
  bool _m2 = false;
  bool _m3 = false;
  bool _loaded = false;

  String _key(String id) {
    final n = DateTime.now();
    return 'mission_${n.year}_${n.month}_${n.day}_$id';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _m1 = p.getBool(_key('m1')) ?? false;
      _m2 = p.getBool(_key('m2')) ?? false;
      _m3 = p.getBool(_key('m3')) ?? false;
      _loaded = true;
    });
  }

  Future<void> _toggle(String id, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key(id), value);
    if (!mounted) return;
    setState(() {
      if (id == 'm1') _m1 = value;
      if (id == 'm2') _m2 = value;
      if (id == 'm3') _m3 = value;
    });
  }

  Future<void> _openLoot() async {
    final xp = 10 + Random().nextInt(41);
    await ref.read(streakFBProvider.notifier).trackLootOpened(xpAwarded: xp);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loot opened: +$xp XP')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Missions')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _mission(
                    title: 'Read 3 slang words',
                    done: _m1,
                    onChanged: (v) => _toggle('m1', v),
                  ),
                  _mission(
                    title: 'Complete 1 quiz',
                    done: _m2,
                    onChanged: (v) => _toggle('m2', v),
                  ),
                  _mission(
                    title: 'Share 1 card',
                    done: _m3,
                    onChanged: (v) => _toggle('m3', v),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _openLoot,
                    icon: const Icon(Icons.redeem_rounded),
                    label: const Text('Open Loot Box'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _mission({
    required String title,
    required bool done,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Switch(value: done, onChanged: onChanged),
        ],
      ),
    );
  }
}
