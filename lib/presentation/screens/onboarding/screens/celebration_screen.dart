import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/fitai_plate_logo.dart';
import '../../../widgets/press_scale.dart';

class CelebrationScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const CelebrationScreen({super.key, required this.onContinue});

  static const Color _emerald = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final name = provider.name.trim().isEmpty ? 'friend' : provider.name.trim();

    return Scaffold(
      backgroundColor: _emerald,
      body: SafeArea(
        child: Stack(
          children: [
            const _CelebrationBackdrop(),
            const _ConfettiLayer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _CelebrationHero()
                      .animate()
                      .fadeIn(duration: 380.ms)
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1, 1),
                        duration: 460.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 28),
                  Text(
                        "You're all set, $name!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.08,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 380.ms, delay: 320.ms)
                      .slideY(
                        begin: 0.20,
                        end: 0,
                        duration: 380.ms,
                        delay: 320.ms,
                      ),
                  const SizedBox(height: 12),
                  Text(
                    'Your personalized nutrition plan is ready. The next time you open FitAI, your dashboard will already feel tailored to you.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.55,
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 420.ms),
                  const SizedBox(height: 24),
                  Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _MiniMetric(
                                  label: 'Goal',
                                  value: provider.primaryGoal ?? 'Feel better',
                                ),
                                const SizedBox(width: 10),
                                _MiniMetric(
                                  label: 'Target',
                                  value:
                                      '${provider.targetWeightKg.round()} kg',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _MiniMetric(
                                  label: 'Pace',
                                  value: provider.resultPaceLabel,
                                ),
                                const SizedBox(width: 10),
                                _MiniMetric(label: 'Plan', value: 'Ready'),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 360.ms, delay: 540.ms)
                      .slideY(
                        begin: 0.18,
                        end: 0,
                        duration: 360.ms,
                        delay: 540.ms,
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
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Enter FitAI',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _emerald,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 760.ms)
                      .slideY(
                        begin: 0.30,
                        end: 0,
                        duration: 500.ms,
                        delay: 760.ms,
                        curve: Curves.elasticOut,
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

class _CelebrationHero extends StatelessWidget {
  const _CelebrationHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 174,
            height: 174,
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
          const FitAiPlateLogo(size: 108),
          Positioned(
            top: 26,
            right: 34,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const Positioned(
            left: 18,
            top: 60,
            child: _HeroChip(icon: Icons.auto_awesome_rounded, label: 'ready'),
          ),
          const Positioned(
            right: 12,
            bottom: 24,
            child: _HeroChip(icon: Icons.favorite_rounded, label: 'personal'),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CelebrationScreen._emerald),
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

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.96),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationBackdrop extends StatelessWidget {
  const _CelebrationBackdrop();

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
                  colors: [
                    AppColors.primaryLight,
                    CelebrationScreen._emerald,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 92,
            left: -24,
            right: -24,
            child: Transform.rotate(
              angle: -0.04,
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
          Positioned(
            left: -18,
            right: -18,
            bottom: 122,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer();

  static const List<Color> _colors = [
    Colors.white,
    AppColors.amber,
    AppColors.sage,
    AppColors.surfaceSoft,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (int i = 0; i < 14; i++)
              _ConfettiParticle(
                index: i,
                color: _colors[i % _colors.length],
                left: ((i * 43) % 100) / 100 * constraints.maxWidth,
                fallDistance: constraints.maxHeight + 120,
              ),
          ],
        );
      },
    );
  }
}

class _ConfettiParticle extends StatelessWidget {
  final int index;
  final Color color;
  final double left;
  final double fallDistance;

  const _ConfettiParticle({
    required this.index,
    required this.color,
    required this.left,
    required this.fallDistance,
  });

  @override
  Widget build(BuildContext context) {
    final size = 8.0 + (index % 5);
    final duration = Duration(milliseconds: 2200 + (index % 5) * 380);
    final delay = Duration(milliseconds: index * 120);
    final wobble = 18.0 + (index % 4) * 8;
    final circle = index.isEven;

    return Positioned(
      top: -80,
      left: left,
      child: Transform.rotate(
        angle: index * math.pi / 7,
        child:
            Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: circle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circle ? null : BorderRadius.circular(2),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .moveY(
                  begin: -20,
                  end: fallDistance,
                  duration: duration,
                  delay: delay,
                  curve: Curves.linear,
                )
                .moveX(
                  begin: -wobble,
                  end: wobble,
                  duration: Duration(
                    milliseconds: duration.inMilliseconds ~/ 2,
                  ),
                  delay: delay,
                  curve: Curves.easeInOutSine,
                )
                .then()
                .moveX(
                  begin: wobble,
                  end: -wobble,
                  duration: Duration(
                    milliseconds: duration.inMilliseconds ~/ 2,
                  ),
                  curve: Curves.easeInOutSine,
                ),
      ),
    );
  }
}
