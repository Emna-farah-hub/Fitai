import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../widgets/fitai_brand_mark.dart';
import '../../../widgets/onboarding_bottom_nav.dart';

class SocialProofScreen extends StatelessWidget {
  final VoidCallback onNext;

  const SocialProofScreen({super.key, required this.onNext});

  static const Color _bg = AppColors.backgroundAlt;
  static const Color _brand = AppColors.primary;
  static const Color _dark = AppColors.textPrimary;
  static const Color _muted = AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            const _AmbientBackdrop(),
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                    child: Column(
                      children: [
                        const _HeroComposition()
                            .animate()
                            .fadeIn(duration: 420.ms)
                            .slideY(
                              begin: 0.12,
                              end: 0,
                              duration: 420.ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 30),
                        Text(
                              'A nutrition plan that adapts to you.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: _dark,
                                height: 1.06,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 320.ms, delay: 140.ms)
                            .slideY(
                              begin: 0.18,
                              end: 0,
                              duration: 320.ms,
                              delay: 140.ms,
                            ),
                        const SizedBox(height: 14),
                        Text(
                              'FitAI learns your goal, your rhythm, and the meals you actually enjoy so every next step feels personal.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _muted,
                                height: 1.6,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 320.ms, delay: 220.ms)
                            .slideY(
                              begin: 0.16,
                              end: 0,
                              duration: 320.ms,
                              delay: 220.ms,
                            ),
                        const SizedBox(height: 24),
                        for (int i = 0; i < _features.length; i++) ...[
                          _FeaturePanel(feature: _features[i])
                              .animate()
                              .fadeIn(
                                duration: 300.ms,
                                delay: Duration(milliseconds: 340 + i * 90),
                              )
                              .slideY(
                                begin: 0.18,
                                end: 0,
                                duration: 300.ms,
                                delay: Duration(milliseconds: 340 + i * 90),
                                curve: Curves.easeOutCubic,
                              ),
                          if (i < _features.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                OnboardingBottomNav(
                  onNext: onNext,
                  nextLabel: 'Start setup',
                  accentColor: _brand,
                ).animate().fadeIn(duration: 340.ms, delay: 640.ms),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const List<_Feature> _features = [
  _Feature(
    Icons.flag_rounded,
    'Goal-aware',
    'Calorie and coaching guidance shaped around what you want to achieve.',
  ),
  _Feature(
    Icons.dinner_dining_rounded,
    'Meal-smart',
    'Recipes and suggestions tuned to your tastes, routine, and energy.',
  ),
  _Feature(
    Icons.auto_awesome_rounded,
    'Coach-led',
    'A calmer AI assistant that learns and gets more helpful over time.',
  ),
];

class _Feature {
  final IconData icon;
  final String title;
  final String body;

  const _Feature(this.icon, this.title, this.body);
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1F16A34A),
                    Color(0x0816A34A),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: 100,
            child: Container(
              width: 180,
              height: 180,
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

class _HeroComposition extends StatelessWidget {
  const _HeroComposition();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 292,
      height: 252,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0x2616A34A),
                    const Color(0x0816A34A),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 194,
              height: 202,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.amberSoft, AppColors.surfaceSoft],
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'adaptive AI',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: SocialProofScreen._brand,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Align(
                      alignment: Alignment.center,
                      child: FitAiBrandMark(size: 96, playEntrance: false),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(child: _StatBar(widthFactor: 0.88)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatBar(widthFactor: 0.52)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatBar(widthFactor: 0.72)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 10,
            top: 44,
            child: _OrbitChip(
              icon: Icons.track_changes_rounded,
              label: 'goal-first',
              tint: AppColors.amber,
            ),
          ),
          const Positioned(
            right: 6,
            top: 82,
            child: _OrbitChip(
              icon: Icons.favorite_rounded,
              label: 'meal taste',
              tint: AppColors.sage,
            ),
          ),
          const Positioned(
            bottom: 14,
            child: _OrbitChip(
              icon: Icons.auto_graph_rounded,
              label: 'learning plan',
              tint: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;

  const _OrbitChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SocialProofScreen._dark,
                ),
              ),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: -3, end: 3, duration: 1900.ms, curve: Curves.easeInOut);
  }
}

class _StatBar extends StatelessWidget {
  final double widthFactor;

  const _StatBar({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _FeaturePanel extends StatelessWidget {
  final _Feature feature;

  const _FeaturePanel({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
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
              color: SocialProofScreen._brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              feature.icon,
              color: SocialProofScreen._brand,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: SocialProofScreen._dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: SocialProofScreen._muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
