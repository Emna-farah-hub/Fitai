import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/nutrition_calculator.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 3: Height — slider with cm / inch toggle.
class StepHeight extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepHeight({super.key, required this.onNext, required this.onBack});

  @override
  State<StepHeight> createState() => _StepHeightState();
}

class _StepHeightState extends State<StepHeight> {
  bool _useCm = true;

  String _displayValue(double cm) {
    if (_useCm) return '${cm.round()} cm';
    final inches = NutritionCalculator.cmToInches(cm);
    final feet = (inches / 12).floor();
    final remainingInches = (inches % 12).round();
    return "$feet' $remainingInches\"";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final displayCm = provider.heightCm;
        final displayInch = NutritionCalculator.cmToInches(displayCm);

        return OnboardingScaffold(
          currentStep: provider.currentStep,
          totalSteps: provider.totalSteps,
          question: AppStrings.onboardingTitles[3],
          questionSubtitle: AppStrings.onboardingSubtitles[3],
          onBack: widget.onBack,
          onContinue: widget.onNext,
          content: Column(
            children: [
              // Unit toggle
              _UnitToggle(
                useCm: _useCm,
                onToggle: (v) => setState(() => _useCm = v),
              ),
              const SizedBox(height: 24),
              // Large value display
              Text(
                _displayValue(displayCm),
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -1,
                ),
              ),
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
                  value: _useCm ? displayCm : displayInch,
                  min: _useCm ? 100 : 39,
                  max: _useCm ? 230 : 90,
                  divisions: _useCm ? 130 : 51,
                  onChanged: (v) {
                    final cm = _useCm ? v : NutritionCalculator.inchesToCm(v);
                    context.read<OnboardingProvider>().setHeight(cm);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_useCm ? '100 cm' : "3'3\"",
                      style: _rangeStyle()),
                  Text(_useCm ? '230 cm' : "7'6\"",
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

class _UnitToggle extends StatelessWidget {
  final bool useCm;
  final ValueChanged<bool> onToggle;

  const _UnitToggle({required this.useCm, required this.onToggle});

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
          _Tab(label: 'cm', selected: useCm, onTap: () => onToggle(true)),
          _Tab(label: 'inch', selected: !useCm, onTap: () => onToggle(false)),
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
