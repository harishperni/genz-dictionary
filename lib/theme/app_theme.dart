import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C4DFF), // neon purple
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  return base.copyWith(
    textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0B0B11),

    // 🔧 Flutter 3.22+ wants CardThemeData here
    cardTheme: CardThemeData(
      color: Colors.white.withOpacity(0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      hintStyle: const TextStyle(color: Colors.white70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

BoxDecoration neonGradientBackground() => const BoxDecoration(
  gradient: LinearGradient(
    colors: [Color(0xFF0B0B11), Color(0xFF12122A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

BoxDecoration glassCard() => BoxDecoration(
  color: Colors.white.withOpacity(0.06),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.white.withOpacity(0.08)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF7C4DFF).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    )
  ],
);
