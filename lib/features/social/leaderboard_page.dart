import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'rank_utils.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Global'),
              Tab(text: 'City'),
              Tab(text: 'Campus'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _meDoc(),
            builder: (context, meSnap) {
              final me = meSnap.data?.data() ?? const <String, dynamic>{};
              final city = (me['city'] ?? '').toString().trim();
              final campus = (me['campus'] ?? '').toString().trim();

              return TabBarView(
                children: [
                  _LeaderboardList(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .orderBy('xp', descending: true)
                        .limit(30)
                        .snapshots(),
                    title: 'Season Rank • Global',
                  ),
                  _ScopedLeaderboard(
                    title: city.isEmpty ? 'Set your city in profile' : 'City: $city',
                    field: 'city',
                    value: city,
                  ),
                  _ScopedLeaderboard(
                    title: campus.isEmpty
                        ? 'Set your campus in profile'
                        : 'Campus: $campus',
                    field: 'campus',
                    value: campus,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _meDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return FirebaseFirestore.instance.collection('users').doc('_missing').get();
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }
}

class _ScopedLeaderboard extends StatelessWidget {
  final String title;
  final String field;
  final String value;

  const _ScopedLeaderboard({
    required this.title,
    required this.field,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return Center(
        child: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    final stream =
        FirebaseFirestore.instance.collection('users').where(field, isEqualTo: value).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Could not load leaderboard:\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ax = ((a.data()['xp'] ?? 0) as num).toInt();
            final bx = ((b.data()['xp'] ?? 0) as num).toInt();
            return bx.compareTo(ax);
          });
        return _LeaderboardListView(title: title, docs: docs.take(30).toList());
      },
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String title;

  const _LeaderboardList({required this.stream, required this.title});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Could not load leaderboard:\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return _LeaderboardListView(title: title, docs: snap.data!.docs);
      },
    );
  }
}

class _LeaderboardListView extends StatelessWidget {
  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _LeaderboardListView({required this.title, required this.docs});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'No players ranked yet.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.86),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final rank = i + 1;
              final xp = (data['xp'] is int)
                  ? data['xp'] as int
                  : int.tryParse('${data['xp'] ?? 0}') ?? 0;
              final level = (data['level'] is int)
                  ? data['level'] as int
                  : int.tryParse('${data['level'] ?? 1}') ?? 1;
              final displayId = (data['displayId'] ?? '').toString().trim();
              final name = displayId.isNotEmpty ? displayId : _shortId(docs[i].id);
              final seasonRank = seasonalRankForXP(xp);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? const Color(0xFF34D399).withOpacity(0.25)
                            : Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$seasonRank • Lv.$level',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _shortId(String id) {
    if (id.length <= 6) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 2)}';
  }
}
