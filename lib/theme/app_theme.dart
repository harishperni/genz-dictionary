import 'package:flutter/material.dart';

/// ---------- App Theme (Material 3, dark neon) ----------
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final seed = const Color(0xFF7C3AED); // neon purple
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D1021),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// ---------- Reusable background & card helpers ----------

/// Neon gradient background for top-level containers.
/// Usage: `decoration: neonGradientBackground(),`
BoxDecoration neonGradientBackground() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}

/// Glassy card look used across the app.
/// Usage: `decoration: glassCard(),`
BoxDecoration glassCard() {
  return BoxDecoration(
    color: Colors.white.withOpacity(0.06),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.12)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.25),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}