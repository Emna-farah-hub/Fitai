import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/fitai_plate_logo.dart';
import '../../../widgets/press_scale.dart';

class AiCoachScreen extends StatefulWidget {
  final VoidCallback onNext;

  const AiCoachScreen({super.key, required this.onNext});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  static const String _line = "I'm your FitAI coach.";
  int _visibleChars = 0;

  @override
  void initState() {
    super.initState();
    _typeLine();
  }

  Future<void> _typeLine() async {
    for (int i = 1; i <= _line.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 22));
      if (!mounted) return;
      setState(() => _visibleChars = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final name = provider.name.trim().isEmpty ? 'there' : provider.name.trim();

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(
        child: Stack(
          children: [
            const _CoachBackdrop(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _CoachHero()
                      .animate()
                      .fadeIn(duration: 360.ms)
                      .slideY(
                        begin: 0.12,
                        end: 0,
                        duration: 360.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 28),
                  Text(
                    'Hi $name,',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _line.substring(0, _visibleChars),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'I’ll guide your meals, calorie target, and motivation with a calmer, more personal experience.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ).animate().fadeIn(duration: 280.ms, delay: 180.ms),
                  const SizedBox(height: 26),
                  const _CoachCapabilityCard(
                    icon: Icons.insights_rounded,
                    title: 'Track your nutrition',
                    body:
                        'Progress, meals, and patterns stay easy to understand.',
                    delayMs: 200,
                  ),
                  const SizedBox(height: 12),
                  const _CoachCapabilityCard(
                    icon: Icons.local_dining_rounded,
                    title: 'Suggest meals you’ll love',
                    body:
                        'Recommendations adapt to your taste instead of feeling generic.',
                    delayMs: 320,
                  ),
                  const SizedBox(height: 12),
                  const _CoachCapabilityCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Check in when it matters',
                    body: 'Encouragement arrives with warmth, not pressure.',
                    delayMs: 440,
                  ),
                  const Spacer(flex: 3),
                  PressScale(
                    onPressed: widget.onNext,
                    pressedScale: 0.97,
                    invokeDelay: const Duration(milliseconds: 50),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.primaryDark,
                              AppColors.primaryLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Meet my coach',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachBackdrop extends StatelessWidget {
  const _CoachBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -26,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1416A34A),
                    Color(0x0416A34A),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: 170,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x14F2B441),
                    Color(0x04F2B441),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachHero extends StatelessWidget {
  const _CoachHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 286,
      height: 170,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 22,
            child: Container(
              height: 122,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 0,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surface, AppColors.surfaceSoft],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Center(child: FitAiPlateLogo(size: 76, float: true)),
            ),
          ),
          Positioned(
            right: 16,
            top: 36,
            child: Container(
              width: 132,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'Personal meal guidance that actually feels human.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 90,
            bottom: 0,
            child: _CoachChip(
              icon: Icons.auto_awesome_rounded,
              label: 'coaching',
            ),
          ),
          const Positioned(
            right: 18,
            bottom: 10,
            child: _CoachChip(icon: Icons.eco_rounded, label: 'habits'),
          ),
        ],
      ),
    );
  }
}

class _CoachChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CoachChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCapabilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final int delayMs;

  const _CoachCapabilityCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.94)),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: Duration(milliseconds: delayMs),
        )
        .slideY(
          begin: 0.18,
          end: 0,
          duration: 300.ms,
          delay: Duration(milliseconds: delayMs),
        );
  }
}
