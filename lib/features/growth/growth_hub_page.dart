import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GrowthHubPage extends StatelessWidget {
  const GrowthHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GenZ+ Hub')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: GridView.count(
          padding: const EdgeInsets.all(14),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _tile(context, 'AI Coach', Icons.auto_awesome_rounded, 'ai_coach'),
            _tile(context, 'Persona Quiz', Icons.psychology_alt_rounded,
                'persona_quiz'),
            _tile(context, 'Daily Missions', Icons.task_alt_rounded,
                'daily_missions'),
            _tile(context, 'Near Me Trends', Icons.location_on_rounded,
                'trends_near_me'),
            _tile(context, 'Creator Packs', Icons.groups_rounded,
                'creator_packs'),
            _tile(context, 'Community Feed', Icons.forum_rounded,
                'community_feed'),
            _tile(context, 'Moderation', Icons.gavel_rounded, 'moderation'),
          ],
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, String title, IconData icon, String routeName) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.pushNamed(routeName),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: const Color(0xFF7DD3FC)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
