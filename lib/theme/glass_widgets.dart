import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;
  final double bgOpacity;
  final double borderOpacity;

  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.radius = 16,
    this.blur = 10,
    this.bgOpacity = 0.06,
    this.borderOpacity = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(bgOpacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Slightly bigger "card" version (for question card / option tile)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.blur = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPill(
      padding: padding,
      radius: radius,
      blur: blur,
      bgOpacity: 0.07,
      borderOpacity: 0.14,
      child: child,
    );
  }
}