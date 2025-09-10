// lib/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'features/slang/ui/search_page.dart';
import 'features/slang/ui/detail_page.dart';
import 'features/slang/ui/favorites_page.dart';
import 'features/slang/ui/quiz_page.dart';
import 'features/streak/badges_page.dart';

/// Same routes you had working before
GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const SearchPage(),
          routes: [
            GoRoute(
              path: 'detail/:term',
              name: 'detail',
              builder: (context, state) {
                final raw = state.pathParameters['term']!;
                final term = Uri.decodeComponent(raw);
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
          ],
        ),
      ],
    );

class GenZApp extends StatelessWidget {
  const GenZApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gen Z Dictionary',
      routerConfig: router,
      // Keep theme consistent (fixes brightness assertion)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
    );
  }
}