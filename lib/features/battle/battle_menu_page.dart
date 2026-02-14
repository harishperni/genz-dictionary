import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:genz_dictionary/theme/glass_widgets.dart';

class BattleMenuPage extends StatelessWidget {
  const BattleMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1021), Color(0xFF1F1147)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    const _LogoMark(),
                    const SizedBox(width: 10),
                    const Text(
                      'GenZ Dict',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    GlassPill(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sports_kabaddi_rounded,
                            color: Colors.white.withOpacity(0.85),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Battle',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Title
              const Icon(
                Icons.sports_kabaddi_rounded,
                color: Color(0xFFFF4FD8),
                size: 54,
              ),
              const SizedBox(height: 12),
              const Text(
                'Battle Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Challenge a friend to a slang-off.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 26),

              // Cards (Create / Join)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;

                    final createCard = _ActionCard(
                      icon: Icons.flash_on_rounded,
                      iconColor: const Color(0xFFA855F7),
                      title: 'Create Game',
                      subtitle: 'Host a new lobby and invite a friend.',
                      buttonText: 'Create Lobby',
                      buttonColor: const Color(0xFFA855F7),
                      onPressed: () => context.pushNamed('create_lobby'),
                    );

                    final joinCard = _ActionCard(
                      icon: Icons.people_alt_rounded,
                      iconColor: const Color(0xFF22D3EE),
                      title: 'Join Game',
                      subtitle: 'Enter a code to join a friend’s lobby.',
                      buttonText: 'Join Lobby',
                      buttonColor: const Color(0xFF22D3EE),
                      onPressed: () => context.pushNamed('join_lobby'),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: createCard),
                          const SizedBox(width: 18),
                          Expanded(child: joinCard),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        createCard,
                        const SizedBox(height: 16),
                        joinCard,
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Battle Stats button (placed OUTSIDE the LayoutBuilder)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed('battle_stats'),
                    icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
                    label: const Text(
                      'Battle Stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  '© 2026 Gen Z Dictionary',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text(
          'Z',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onPressed,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}