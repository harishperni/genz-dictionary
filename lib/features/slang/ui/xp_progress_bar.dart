import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../streak/streak_controller_firebase.dart';

class XPProgressBar extends ConsumerStatefulWidget {
  const XPProgressBar({super.key});

  @override
  XPProgressBarState createState() => XPProgressBarState();
}

class XPProgressBarState extends ConsumerState<XPProgressBar>
    with TickerProviderStateMixin {
  bool _showGain = false;
  int _lastGain = 0;

  // Popup animation
  late final AnimationController _popupCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  // Glow animation (near level-up)
  late final AnimationController _glowCtrl;

  // Smooth progress animation
  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  Timer? _hideTimer;

  int _lastXp = -1;

  @override
  void initState() {
    super.initState();

    // +XP popup animation
    _popupCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: const Offset(0, -0.75),
    ).animate(CurvedAnimation(
      parent: _popupCtrl,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _popupCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    ));

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.10).animate(CurvedAnimation(
      parent: _popupCtrl,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
    ));

    // Glow controller
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // Smooth progress controller
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _popupCtrl.dispose();
    _glowCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  int _levelFromXP(int xp) => (xp / 100).floor() + 1;
  int _xpForNextLevel(int level) => level * 100;

  double _progressForXP(int xp) {
    final level = _levelFromXP(xp);
    final prevXP = _xpForNextLevel(level - 1);
    final nextXP = _xpForNextLevel(level);
    final p = (xp - prevXP) / (nextXP - prevXP);
    return p.clamp(0.0, 1.0);
  }

  void _animateToProgress(double nextProgress) {
    final current = _progressAnim.value;
    _progressCtrl.stop();
    _progressAnim = Tween<double>(
      begin: current,
      end: nextProgress,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic));
    _progressCtrl
      ..reset()
      ..forward();
  }

  void _setGlowForProgress(double progress) {
    // Only glow when you're close to leveling up
    if (progress >= 0.95) {
      if (!_glowCtrl.isAnimating && _glowCtrl.value < 1) {
        _glowCtrl.forward();
      }
    } else {
      if (!_glowCtrl.isAnimating && _glowCtrl.value > 0) {
        _glowCtrl.reverse();
      }
    }
  }

  /// called from SearchPage using `xpBarKey.currentState?.showXPGain(50)`
  void showXPGain(int amount) {
    _hideTimer?.cancel();

    setState(() {
      _lastGain = amount;
      _showGain = true;
    });

    _popupCtrl
      ..stop()
      ..reset()
      ..forward();

    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _showGain = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakFBProvider);
    final xp = streak.xp ?? 0;

    final level = _levelFromXP(xp);
    final nextXP = _xpForNextLevel(level);
    final progressTarget = _progressForXP(xp);

    // ✅ React to XP changes WITHOUT triggering animations inside build repeatedly
    if (_lastXp != xp) {
      _lastXp = xp;
      _animateToProgress(progressTarget);
      _setGlowForProgress(progressTarget);
    }

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // XP Bar card
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (context, _) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.lightBlueAccent.withOpacity(0.28 * _glowCtrl.value),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (context, _) {
                          final p = _progressAnim.value.clamp(0.0, 1.0);
                          return LinearProgressIndicator(
                            value: p,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              p >= 1.0 ? Colors.amberAccent : Colors.lightBlueAccent,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${xp.toInt()} / $nextXP XP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ✨ Floating +XP popup
          if (_showGain)
            Positioned(
              top: -8,
              right: 20,
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4AF1A6), Color(0xFF27AE60)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '+$_lastGain XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.greenAccent,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}