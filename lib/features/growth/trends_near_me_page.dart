import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TrendsNearMePage extends StatelessWidget {
  const TrendsNearMePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _myProfile(),
      builder: (context, snap) {
        final city = (snap.data?.data()?['city'] ?? '').toString().trim();
        final q = city.isEmpty
            ? FirebaseFirestore.instance
                .collection('community_submissions')
                .where('status', isEqualTo: 'approved')
                .orderBy('createdAt', descending: true)
                .limit(60)
            : FirebaseFirestore.instance
                .collection('community_submissions')
                .where('status', isEqualTo: 'approved')
                .where('city', isEqualTo: city)
                .orderBy('createdAt', descending: true)
                .limit(60);

        return Scaffold(
          appBar: AppBar(
            title: Text(city.isEmpty ? 'Trends (Global)' : 'Today in $city'),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, s) {
                if (s.hasError) {
                  return Center(
                    child: Text(
                      'Could not load trends:\n${s.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final docs = s.data!.docs;
                final top = _topTerms(docs);
                if (top.isEmpty) {
                  return const Center(
                    child: Text(
                      'No trends yet.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: top.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = top[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '#${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFF7DD3FC),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value} mentions',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _myProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return FirebaseFirestore.instance.collection('users').doc('_none').get();
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  List<MapEntry<String, int>> _topTerms(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final m = <String, int>{};
    for (final d in docs) {
      final t = (d.data()['term'] ?? '').toString().trim();
      if (t.isEmpty) continue;
      m[t] = (m[t] ?? 0) + 1;
    }
    final out = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return out.take(20).toList();
  }
}
