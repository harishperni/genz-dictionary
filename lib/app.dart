import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🏠 Core feature imports
import 'features/slang/ui/search_page.dart';
import 'features/slang/ui/detail_page.dart';
import 'features/slang/ui/favorites_page.dart';
import 'features/slang/ui/quiz_page.dart';

// 🏅 Streaks & Badges
import 'features/streak/badges_page.dart';

// ⚔️ Battle Mode
import 'features/battle/battle_menu_page.dart';
import 'features/battle/create_lobby_page.dart';
import 'features/battle/join_lobby_page.dart';
import 'features/battle/battle_quiz_page.dart';
import 'features/battle/battle_stats_page.dart'; // ✅ make sure this file exists

// 🎨 Theme
import 'theme/genz_style.dart';

// 🧪 Debug
import 'features/streak/debug_streak_panel.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  /// Always returns a non-null uid for routing.
  /// If you are not logged in yet, it will fall back to 'demo_user_1'.
  /// (You can replace fallback with a login redirect later.)
  String _uidOrDemo([String? extraUid]) {
    return extraUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        'demo_user_1';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        /// 🏠 HOME (Search)
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const SearchPage(),
          routes: [
            GoRoute(
              path: 'detail/:term',
              name: 'detail',
              builder: (context, state) {
                final term = Uri.decodeComponent(state.pathParameters['term']!);
                return DetailPage(term: term);
              },
            ),
            GoRoute(
              path: 'favorites',
              name: 'favorites',
              builder: (context, state) => const FavoritesPage(),
            ),
            GoRoute(
              path: 'quiz',
              name: 'quiz',
              builder: (context, state) => const QuizPage(),
            ),
            GoRoute(
              path: 'badges',
              name: 'badges',
              builder: (context, state) => const BadgesPage(),
            ),

            /// ⚔️ Battle menu + children
            GoRoute(
              path: 'battle',
              name: 'battle_menu',
              builder: (context, state) {
                final uid = FirebaseAuth.instance.currentUser?.uid ?? 'demo_user_1';
                return BattleMenuPage(userId: uid);
                },
              routes: [
                GoRoute(
                  path: 'create',
                  name: 'create_lobby',
                  builder: (context, state) => const CreateLobbyPage(),
                ),
                GoRoute(
                  path: 'join',
                  name: 'join_lobby',
                  builder: (context, state) => const JoinLobbyPage(),
                ),
              ],
            ),

            /// ⚔️ Battle quiz route (expects :code)
            /// We pass uid via state.extra OR fallback to FirebaseAuth uid.
            GoRoute(
              path: 'battle/quiz/:code',
              name: 'battle_quiz',
              builder: (context, state) {
                final code = state.pathParameters['code']!;
                final extraUid = state.extra as String?;
                final uid = _uidOrDemo(extraUid);
                return BattleQuizPage(code: code, userId: uid);
              },
            ),
          ],
        ),

        /// 📊 Battle Stats (Top-level route)
        /// We pass uid via state.extra OR fallback to FirebaseAuth uid.
        GoRoute(
          path: '/battle-stats',
          name: 'battle_stats',
          //builder: (context, state) => const BattleStatsPage(),
          builder: (context, state) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? 'demo_user_1';
            return BattleStatsPage(userId: uid);
          },
          ),

        /// 🧪 DEBUG STREAK PANEL
        GoRoute(
          path: '/debug-streak',
          name: 'debug_streak',
          builder: (_, __) => const DebugStreakPanel(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Gen Z Dictionary',
      debugShowCheckedModeBanner: false,
      theme: GenZTheme.dark(),
      routerConfig: router,
    );
  }
}