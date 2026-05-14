import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/body_ruler_picker.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/press_scale.dart';

class WeightScreen extends StatefulWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const WeightScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  bool _useMetric = true;
  int _lastHapticWeight = 70;
  static const double _kgPerLb = 0.45359237;

  String _weightLabel(double kg) {
    if (_useMetric) return kg.round().toString();
    return _kgToLb(kg).round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final bmi = _calculateBmi(provider.weightKg, provider.heightCm);
        final status = _bmiStatus(bmi);
        final rulerValue = _useMetric
            ? provider.weightKg
            : _kgToLb(provider.weightKg);
        final rulerMin = _useMetric ? 40.0 : _kgToLb(40);
        final rulerMax = _useMetric ? 180.0 : _kgToLb(180);

        return OnboardingQuestionScaffold(
          backgroundColor: widget.paleColor,
          currentSection: widget.currentSection,
          progressInSection: widget.progressInSection,
          accentColor: widget.accentColor,
          onBack: widget.onBack,
          onNext: widget.onNext,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      "What's your current weight?",
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
                      'Combined with your height and age, this helps us set a precise daily calorie target.',
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
                const SizedBox(height: 18),
                Center(
                      child: _UnitToggle(
                        firstLabel: 'kg',
                        secondLabel: 'lb',
                        firstSelected: _useMetric,
                        accentColor: AppColors.tealDark,
                        onChanged: (value) => setState(() {
                          _useMetric = value;
                          _lastHapticWeight =
                              (_useMetric
                                      ? provider.weightKg
                                      : _kgToLb(provider.weightKg))
                                  .round();
                        }),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 240.ms, delay: 160.ms)
                    .slideY(
                      begin: 14 / 44,
                      end: 0,
                      duration: 240.ms,
                      delay: 160.ms,
                    ),
                const SizedBox(height: 24),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Row(
                      key: ValueKey(
                        '${_useMetric}_${provider.weightKg.round()}',
                      ),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _weightLabel(provider.weightKg),
                          style: GoogleFonts.nunito(
                            fontSize: 66,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tealDark,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _useMetric ? 'kg' : 'lb',
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                HorizontalWeightRuler(
                      value: rulerValue,
                      min: rulerMin,
                      max: rulerMax,
                      accentColor: widget.accentColor,
                      onChanged: (value) {
                        final rounded = value.round();
                        if ((rounded - _lastHapticWeight).abs() >= 2) {
                          _lastHapticWeight = rounded;
                          HapticFeedback.selectionClick();
                        }
                        provider.setWeight(_useMetric ? value : _lbToKg(value));
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
                        Icons.monitor_weight_outlined,
                        color: widget.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Only nearby numbers stay visible so the center line is easy to read.',
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
                _BmiCard(bmi: bmi, status: status),
              ],
            ),
          ),
        );
      },
    );
  }

  double _kgToLb(double kg) => kg / _kgPerLb;

  double _lbToKg(double lb) => lb * _kgPerLb;

  double _calculateBmi(double weightKg, double heightCm) {
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  _BmiStatus _bmiStatus(double bmi) {
    if (bmi < 18.5) {
      return const _BmiStatus(
        label: 'Underweight',
        bg: AppColors.amberSoft,
        fg: AppColors.amberDark,
      );
    }
    if (bmi < 25) {
      return const _BmiStatus(
        label: 'Healthy weight',
        bg: AppColors.primarySoft,
        fg: AppColors.primaryDark,
      );
    }
    if (bmi < 30) {
      return const _BmiStatus(
        label: 'Overweight',
        bg: AppColors.amberSoft,
        fg: AppColors.amberDark,
      );
    }
    return const _BmiStatus(
      label: 'Needs attention',
      bg: AppColors.errorSurface,
      fg: AppColors.error,
    );
  }
}

class _BmiStatus {
  final String label;
  final Color bg;
  final Color fg;

  const _BmiStatus({required this.label, required this.bg, required this.fg});
}

class _BmiCard extends StatelessWidget {
  final double bmi;
  final _BmiStatus status;

  const _BmiCard({required this.bmi, required this.status});

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
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.tealDark,
                    ),
                    children: [
                      const TextSpan(text: 'BMI '),
                      TextSpan(
                        text: bmi.toStringAsFixed(1),
                        style: TextStyle(color: status.fg),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: status.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'BMI is only one signal. FitAI also uses your goal, age, height, and routine to personalize your plan.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String firstLabel;
  final String secondLabel;
  final bool firstSelected;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _UnitToggle({
    required this.firstLabel,
    required this.secondLabel,
    required this.firstSelected,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UnitButton(
          label: firstLabel,
          selected: firstSelected,
          accentColor: accentColor,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 8),
        _UnitButton(
          label: secondLabel,
          selected: !firstSelected,
          accentColor: accentColor,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _UnitButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _UnitButton({
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 1.5,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
