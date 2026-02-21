import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/glass_widgets.dart'; // adjust if your path differs

class BattleStatsPage extends ConsumerWidget {
  final String userId;
  const BattleStatsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = FirebaseFirestore.instance;
    final statsDoc = db
        .collection('users')
        .doc(userId)
        .collection('battle_stats')
        .doc('main');

    final historyQuery = db
        .collection('users')
        .doc(userId)
        .collection('battle_history')
        .orderBy('recordedAt', descending: true)
        .limit(10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Stats'),
        actions: [
          IconButton(
            tooltip: 'Edit ID',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/profile-setup?mode=edit'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: statsDoc.snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data() ?? {};
                    int asInt(dynamic v) =>
                        (v is int) ? v : (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
                    final total = asInt(data['gamesPlayed']);
                    final wins = asInt(data['wins']);
                    final losses = asInt(data['losses']);
                    final ties = asInt(data['ties']);

                    final rate = total == 0 ? 0 : ((wins / total) * 100).round();

                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Stats',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _miniStat('Total', '$total'),
                              const SizedBox(width: 10),
                              _miniStat('Wins', '$wins'),
                              const SizedBox(width: 10),
                              _miniStat('Losses', '$losses'),
                              const SizedBox(width: 10),
                              _miniStat('Ties', '$ties'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Win rate: $rate%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: historyQuery.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return GlassCard(
                          child: Text(
                            'Error loading history:\n${snap.error}\n\n(If it mentions an index, open the link and create it.)',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }


                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return GlassCard(
                          child: Text(
                            'No battles saved yet.\nPlay a battle and come back here!',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final d = docs[i].data();
                          int asInt(dynamic v) => (v is int)
                              ? v
                              : (v is num)
                                  ? v.toInt()
                                  : int.tryParse('$v') ?? 0;
                          final oppId = (d['opponentId'] ?? '') as String;
                          final myScore = asInt(d['myScore']);
                          final oppScore = asInt(d['opponentScore']);
                          final outcome = (d['outcome'] ?? '') as String;

                          String label;
                          if (outcome == 'tie') {
                            label = 'Tie 🤝';
                          } else if (outcome == 'win') {
                            label = 'Win 🏆';
                          } else if (outcome == 'loss') {
                            label = 'Loss 😭';
                          } else {
                            label = 'Match';
                          }

                          return GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (oppId.isEmpty)
                                        Text(
                                          'vs Unknown',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.72),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      else
                                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                          future: db.collection('users').doc(oppId).get(),
                                          builder: (context, profileSnap) {
                                            final profile =
                                                profileSnap.data?.data() ?? const <String, dynamic>{};
                                            final displayId =
                                                (profile['displayId'] ?? profile['username'])?.toString();
                                            final name = (displayId != null && displayId.trim().isNotEmpty)
                                                ? displayId.trim()
                                                : _short(oppId);
                                            return Text(
                                              'vs $name',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.72),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$myScore - $oppScore',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _miniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  static String _short(String id) {
    if (id.length <= 6) return id;
    return '${id.substring(0, 4)}…${id.substring(id.length - 2)}';
  }
}
