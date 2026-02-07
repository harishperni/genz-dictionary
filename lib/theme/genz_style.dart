import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GenZColors {
  static const bg0 = Color(0xFF05060A);
  static const bg1 = Color(0xFF0B1020);
  static const bg2 = Color(0xFF150A2E);

  static const card = Color(0x14FFFFFF); // white with low opacity
  static const cardBorder = Color(0x22FFFFFF);

  static const text = Color(0xFFF3F4F6);
  static const textMuted = Color(0xFF9CA3AF);

  static const purple = Color(0xFF8B5CF6);
  static const purpleDark = Color(0xFF7C3AED);

  static const teal = Color(0xFF14B8A6);
  static const pink = Color(0xFFEC4899);

  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
}

class GenZGradients {
  static const background = LinearGradient(
    colors: [GenZColors.bg0, GenZColors.bg1, GenZColors.bg2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class GenZTheme {
  static ThemeData dark() {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: GenZColors.bg0,
      colorScheme: base.colorScheme.copyWith(
        primary: GenZColors.purpleDark,
        secondary: GenZColors.teal,
        surface: GenZColors.card,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w800,
          color: GenZColors.text,
        ),
        bodyMedium: GoogleFonts.poppins(
          color: GenZColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GenZColors.text,
        titleTextStyle: GoogleFonts.poppins(
          color: GenZColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GenZColors.purpleDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(200, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintStyle: TextStyle(color: GenZColors.textMuted.withOpacity(0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GenZColors.purpleDark, width: 1.4),
        ),
      ),
    );
  }
}

/// Re-usable glass card like the Replit UI
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: GenZColors.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: GenZColors.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Page background wrapper (same vibe everywhere)
class GradientScaffoldBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GradientScaffoldBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(gradient: GenZGradients.background),
      child: child,
    );
  }
}

/// Accent icon widget (purple/teal/pink)
class AccentIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AccentIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color, size: size);
  }
}