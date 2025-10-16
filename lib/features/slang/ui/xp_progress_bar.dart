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

  late final AnimationController _popupCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();

    // XP popup animation
    _popupCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: const Offset(0, -0.8),
    ).animate(CurvedAnimation(
      parent: _popupCtrl,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _popupCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(
      parent: _popupCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
    ));

    // Glow near level-up
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _popupCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // Level calculation
  int _levelFromXP(int xp) => (xp / 100).floor() + 1;
  int _xpForNextLevel(int level) => level * 100;

  /// 👇 called from SearchPage using `xpBarKey.currentState?.showXPGain(50)`
  Future<void> showXPGain(int amount) async {
    setState(() {
      _lastGain = amount;
      _showGain = true;
    });
    _popupCtrl.reset();
    _popupCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) setState(() => _showGain = false);
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakFBProvider);
    final xp = streak.xp ?? 0;
    final level = _levelFromXP(xp);
    final prevXP = _xpForNextLevel(level - 1);
    final nextXP = _xpForNextLevel(level);
    final progress = (xp - prevXP) / (nextXP - prevXP);

    // Glow animation near level-up
    if (progress > 0.95) {
      _glowCtrl.forward();
    } else {
      _glowCtrl.reverse();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // XP Bar card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.lightBlueAccent.withOpacity(0.3 * _glowCtrl.value),
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
                    fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? Colors.amberAccent
                        : Colors.lightBlueAccent,
                  ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }
}