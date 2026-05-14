import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/fitai_brand_mark.dart';
import '../../../widgets/press_scale.dart';

class MotivationalBridgeScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const MotivationalBridgeScreen({super.key, required this.onContinue});

  static const Color _bg = AppColors.primaryDark;
  static const Color _accent = AppColors.primaryLight;
  static const Color _softGold = AppColors.amber;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final goal = provider.primaryGoal ?? 'your goal';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _BridgeBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _BridgeHero()
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
                        'First step complete.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.04,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 340.ms, delay: 160.ms)
                      .slideY(
                        begin: 0.18,
                        end: 0,
                        duration: 340.ms,
                        delay: 160.ms,
                      ),
                  const SizedBox(height: 12),
                  Text(
                    "FitAI understands where you're headed. Next, we'll tune the plan around your body, routine, and real-life pace.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.55,
                    ),
                  ).animate().fadeIn(duration: 320.ms, delay: 260.ms),
                  const SizedBox(height: 26),
                  _MilestoneCard(goal: goal)
                      .animate()
                      .fadeIn(duration: 380.ms, delay: 420.ms)
                      .slideY(
                        begin: 0.18,
                        end: 0,
                        duration: 380.ms,
                        delay: 420.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const Spacer(flex: 3),
                  PressScale(
                        onPressed: onContinue,
                        pressedScale: 0.97,
                        invokeDelay: const Duration(milliseconds: 50),
                        child: SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Continue',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _bg,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 700.ms)
                      .slideY(
                        begin: 0.32,
                        end: 0,
                        duration: 500.ms,
                        delay: 700.ms,
                        curve: Curves.elasticOut,
                      ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgeHero extends StatelessWidget {
  const _BridgeHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 164,
            height: 164,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const FitAiBrandMark(size: 116, playEntrance: false),
          Positioned(
            right: 34,
            top: 30,
            child:
                Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: MotivationalBridgeScreen._softGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(0.94, 0.94),
                      end: const Offset(1.06, 1.06),
                      duration: 1200.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final String goal;

  const _MilestoneCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: MotivationalBridgeScreen._accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Your direction',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: MotivationalBridgeScreen._accent.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: MotivationalBridgeScreen._accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  goal,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _BridgeProgressPills(),
        ],
      ),
    );
  }
}

class _BridgeProgressPills extends StatelessWidget {
  const _BridgeProgressPills();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _ProgressPill(
            icon: Icons.flag_rounded,
            label: 'Goal locked',
            active: true,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ProgressPill(
            icon: Icons.accessibility_new_rounded,
            label: 'About you next',
            active: false,
          ),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _ProgressPill({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: active
            ? MotivationalBridgeScreen._accent.withValues(alpha: 0.12)
            : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 15,
            color: active
                ? MotivationalBridgeScreen._accent
                : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.primaryDark : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgeBackdrop extends StatelessWidget {
  const _BridgeBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, MotivationalBridgeScreen._bg],
                ),
              ),
            ),
          ),
          Positioned(
            top: 82,
            left: -20,
            right: -20,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Positioned(
            left: -32,
            right: -32,
            bottom: 104,
            child: Transform.rotate(
              angle: 0.04,
              child: Container(
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Positioned(left: 28, top: 118, child: _leaf(26, -0.5)),
          Positioned(right: 28, bottom: 116, child: _leaf(34, 0.4)),
        ],
      ),
    );
  }

  Widget _leaf(double size, double angle) {
    return Transform.rotate(
      angle: angle,
      child:
          Icon(
                Icons.eco_rounded,
                size: size,
                color: Colors.white.withValues(alpha: 0.12),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: -7,
                duration: 1800.ms,
                curve: Curves.easeInOut,
              ),
    );
  }
}
