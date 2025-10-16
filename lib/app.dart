import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// 🏠 Core feature imports
import 'features/slang/ui/search_page.dart';
import 'features/slang/ui/detail_page.dart';
import 'features/slang/ui/favorites_page.dart';
import 'features/slang/ui/quiz_page.dart';

// 🏅 Streaks & Badges
import 'features/streak/badges_page.dart';
import 'features/streak/streak_banner.dart';

// ⚔️ Battle Mode (Phase 1)
import 'features/battle/battle_menu_page.dart';
import 'features/battle/create_lobby_page.dart';
import 'features/battle/join_lobby_page.dart';

// 🎨 Theme
import 'theme/app_theme.dart';

// 🧪 Debug
import 'features/streak/debug_streak_panel.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        /// 🏠 HOME
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
            GoRoute(
              path: 'battle',
              name: 'battle_menu',
              builder: (context, state) => const BattleMenuPage(),
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
          ],
        ),

        /// 🧪 DEBUG STREAK PANEL (move it here!)
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
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}