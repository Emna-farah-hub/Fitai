import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/body_ruler_picker.dart';
import '../../../widgets/onboarding_question_scaffold.dart';

class TargetWeightScreen extends StatefulWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const TargetWeightScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  @override
  State<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends State<TargetWeightScreen> {
  bool _showOverlay = false;
  bool _navigating = false;
  int _lastHapticTarget = 65;

  Future<void> _handleNext() async {
    if (_navigating) return;
    setState(() {
      _showOverlay = true;
      _navigating = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final current = provider.weightKg;
        final min = 40.0;
        final max = math.max(current, min + 0.1);
        final target = provider.targetWeightKg.clamp(min, max).toDouble();
        final loss = math.max(0.0, current - target);
        final percent = current <= 0 ? 0.0 : (loss / current) * 100;
        final months = loss <= 0 ? 0.0 : loss / 1.7;

        return Stack(
          children: [
            OnboardingQuestionScaffold(
              backgroundColor: widget.paleColor,
              currentSection: widget.currentSection,
              progressInSection: widget.progressInSection,
              accentColor: widget.accentColor,
              onBack: _navigating ? null : widget.onBack,
              onNext: _handleNext,
              isNextEnabled: !_navigating,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                          "What's your target weight?",
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
                          'Pick a realistic goal. You can always adjust it later as your plan evolves.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 280.ms, delay: 100.ms)
                        .slideY(
                          begin: 20 / 40,
                          end: 0,
                          duration: 280.ms,
                          delay: 100.ms,
                        ),
                    const SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            target.round().toString(),
                            style: GoogleFonts.nunito(
                              fontSize: 68,
                              fontWeight: FontWeight.w900,
                              color: AppColors.tealDark,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'kg',
                            style: GoogleFonts.nunito(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.tealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    HorizontalWeightRuler(
                          value: target,
                          min: min,
                          max: max,
                          accentColor: widget.accentColor,
                          markers: [
                            WindowRulerMarker(
                              value: current,
                              label: 'Current',
                              color: AppColors.textMuted,
                            ),
                          ],
                          onChanged: (value) {
                            final rounded = value.round();
                            if ((rounded - _lastHapticTarget).abs() >= 2) {
                              _lastHapticTarget = rounded;
                              HapticFeedback.selectionClick();
                            }
                            provider.setTargetWeight(value);
                          },
                        )
                        .animate()
                        .fadeIn(duration: 320.ms, delay: 220.ms)
                        .slideY(
                          begin: 16 / 168,
                          end: 0,
                          duration: 320.ms,
                          delay: 220.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_circle_outlined,
                            color: widget.accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The center line is your goal. Your current weight stays marked for context.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TargetSummaryCard(
                      accentColor: widget.accentColor,
                      current: current,
                      target: target,
                      loss: loss,
                      percent: percent,
                      months: months,
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !_showOverlay,
              child: AnimatedOpacity(
                opacity: _showOverlay ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                              "${provider.name.isEmpty ? 'You' : provider.name}, you've got this.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.15,
                              ),
                            )
                            .animate(target: _showOverlay ? 1 : 0)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1, 1),
                              duration: 400.ms,
                              curve: Curves.elasticOut,
                            )
                            .fadeIn(duration: 160.ms),
                        const SizedBox(height: 10),
                        Text(
                          "Let's build your plan.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TargetSummaryCard extends StatelessWidget {
  final Color accentColor;
  final double current;
  final double target;
  final double loss;
  final double percent;
  final double months;

  const _TargetSummaryCard({
    required this.accentColor,
    required this.current,
    required this.target,
    required this.loss,
    required this.percent,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your goal snapshot',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Current',
                  value: '${current.round()} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  label: 'Target',
                  value: '${target.round()} kg',
                  valueColor: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'To lose',
                  value: '${loss.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  label: 'Healthy pace',
                  value: loss <= 0
                      ? 'Ready now'
                      : '~${months.toStringAsFixed(1)} mo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            loss <= 0
                ? 'You are already at your chosen weight range.'
                : "That's ${percent.toStringAsFixed(1)}% of your current body weight.",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
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
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }
}
