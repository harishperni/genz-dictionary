import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreatorPacksPage extends StatelessWidget {
  const CreatorPacksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('creator_packs')
        .where('active', isEqualTo: true)
        .orderBy('week', descending: true)
        .limit(20)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Creator Collaborations')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasData && snap.data!.docs.isNotEmpty) {
              final docs = snap.data!.docs;
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _packCard(
                  creator: (docs[i].data()['creator'] ?? 'Unknown').toString(),
                  title: (docs[i].data()['title'] ?? 'Weekly Slang Pack')
                      .toString(),
                  description:
                      (docs[i].data()['description'] ?? '').toString(),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(14),
              children: const [
                _StaticPack(
                  creator: 'LenaByte',
                  title: 'Campus Chaos Pack',
                  description: 'Classroom slang, exam-week memes, and dorm chatter.',
                ),
                SizedBox(height: 10),
                _StaticPack(
                  creator: 'RizzRaf',
                  title: 'Dating App Pack',
                  description: 'Flirty phrases and cringe detectors.',
                ),
                SizedBox(height: 10),
                _StaticPack(
                  creator: 'CodeKira',
                  title: 'Tech Creator Pack',
                  description: 'Dev humor and startup-era slang.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _packCard({
    required String creator,
    required String title,
    required String description,
  }) {
    return _StaticPack(creator: creator, title: title, description: description);
  }
}

class _StaticPack extends StatelessWidget {
  final String creator;
  final String title;
  final String description;

  const _StaticPack({
    required this.creator,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'By @$creator',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
