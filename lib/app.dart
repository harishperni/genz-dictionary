// lib/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'features/slang/ui/search_page.dart';
import 'features/slang/ui/detail_page.dart';
import 'features/slang/ui/favorites_page.dart';
import 'features/slang/ui/quiz_page.dart';
import 'features/streak/badges_page.dart';

/// Central router used by MaterialApp.router in main.dart
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