import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/press_scale.dart';

class PaceScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const PaceScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const Map<String, _PaceMetrics> _metrics = {
    'gradual': _PaceMetrics(label: 'Gradual', calories: 2100, monthlyRate: 0.8),
    'moderate': _PaceMetrics(
      label: 'Moderate',
      calories: 1725,
      monthlyRate: 1.7,
    ),
    'ambitious': _PaceMetrics(
      label: 'Ambitious',
      calories: 1350,
      monthlyRate: 3.0,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final selected = provider.resultPace;
        final metrics = _metrics[selected] ?? _metrics['moderate']!;
        final loss = math.max(0.0, provider.weightKg - provider.targetWeightKg);
        final months = metrics.monthlyRate <= 0
            ? 0
            : (loss / metrics.monthlyRate).ceil();

        return OnboardingQuestionScaffold(
          backgroundColor: paleColor,
          currentSection: currentSection,
          progressInSection: progressInSection,
          accentColor: accentColor,
          onBack: onBack,
          onNext: onNext,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'How fast do you want results?',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 280.ms)
                    .slideY(begin: 24 / 26, end: 0, duration: 280.ms),
                const SizedBox(height: 8),
                Text(
                  'Slower is more sustainable. You can always adjust later.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ).animate().fadeIn(duration: 280.ms, delay: 100.ms),
                const SizedBox(height: 24),
                Row(
                      children: [
                        for (final label in _metrics.keys) ...[
                          Expanded(
                            child: _PacePill(
                              label: _metrics[label]!.label,
                              selected: selected == label,
                              accentColor: accentColor,
                              onTap: () => provider.setResultPace(label),
                            ),
                          ),
                          if (label != _metrics.keys.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 280.ms, delay: 180.ms)
                    .slideY(
                      begin: 20 / 44,
                      end: 0,
                      duration: 280.ms,
                      delay: 180.ms,
                    ),
                const SizedBox(height: 24),
                _MetricCard(
                  title: 'Daily calories',
                  value: '${metrics.calories} kcal',
                  icon: Icons.local_fire_department,
                  accentColor: accentColor,
                  valueKey: selected,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Monthly change',
                        value: '${metrics.monthlyRate.toStringAsFixed(1)} kg',
                        accentColor: accentColor,
                        valueKey: selected,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: 'Reach goal in',
                        value: months <= 0 ? '~0 months' : '~$months months',
                        accentColor: accentColor,
                        valueKey: selected,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaceMetrics {
  final String label;
  final int calories;
  final double monthlyRate;

  const _PaceMetrics({
    required this.label,
    required this.calories,
    required this.monthlyRate,
  });
}

class _PacePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _PacePill({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onPressed: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 2,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color accentColor;
  final String valueKey;
  final bool compact;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.accentColor,
    required this.valueKey,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.24),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    value,
                    key: ValueKey('$valueKey-$title-$value'),
                    style: GoogleFonts.nunito(
                      fontSize: compact ? 21 : 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 12),
            Icon(icon, color: accentColor, size: 30),
          ],
        ],
      ),
    );
  }
}
