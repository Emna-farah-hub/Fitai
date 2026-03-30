import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/nutrition_calculator.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 4: Weight — slider with kg / lb toggle.
class StepWeight extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepWeight({super.key, required this.onNext, required this.onBack});

  @override
  State<StepWeight> createState() => _StepWeightState();
}

class _StepWeightState extends State<StepWeight> {
  bool _useKg = true;

  String _displayValue(double kg) {
    if (_useKg) return '${kg.round()} kg';
    return '${NutritionCalculator.kgToLbs(kg).round()} lbs';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final kg = provider.weightKg;

        return OnboardingScaffold(
          currentStep: provider.currentStep,
          totalSteps: provider.totalSteps,
          question: AppStrings.onboardingTitles[4],
          questionSubtitle: AppStrings.onboardingSubtitles[4],
          onBack: widget.onBack,
          onContinue: widget.onNext,
          content: Column(
            children: [
              // Unit toggle
              _UnitToggle(
                useKg: _useKg,
                onToggle: (v) => setState(() => _useKg = v),
              ),
              const SizedBox(height: 24),
              // Large display
              Text(
                _displayValue(kg),
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              // BMI indicator (rough)
              _BmiIndicator(weightKg: kg),
              const SizedBox(height: 24),
              // Slider
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _useKg ? kg : NutritionCalculator.kgToLbs(kg),
                  min: _useKg ? 30 : 66,
                  max: _useKg ? 200 : 440,
                  divisions: _useKg ? 170 : 374,
                  onChanged: (v) {
                    final weightKg = _useKg ? v : NutritionCalculator.lbsToKg(v);
                    context.read<OnboardingProvider>().setWeight(weightKg);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_useKg ? '30 kg' : '66 lbs',
                      style: _rangeStyle()),
                  Text(_useKg ? '200 kg' : '440 lbs',
                      style: _rangeStyle()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _rangeStyle() => GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textMuted,
      );
}

/// Simple BMI hint based on weight only (height not available yet)
class _BmiIndicator extends StatelessWidget {
  final double weightKg;

  const _BmiIndicator({required this.weightKg});

  @override
  Widget build(BuildContext context) {
    return Text(
      'We\'ll calculate your BMI after you enter your height',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final bool useKg;
  final ValueChanged<bool> onToggle;

  const _UnitToggle({required this.useKg, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Tab(label: 'kg', selected: useKg, onTap: () => onToggle(true)),
          _Tab(label: 'lbs', selected: !useKg, onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
