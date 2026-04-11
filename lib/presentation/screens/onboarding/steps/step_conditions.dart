import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 8: Health conditions — multi-select chips.
/// Selecting "None" clears all others; selecting any other clears "None".
class StepConditions extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepConditions({super.key, required this.onNext, required this.onBack});

  static const _conditions = AppStrings.healthConditions;

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) => OnboardingScaffold(
        currentStep: provider.currentStep,
        totalSteps: provider.totalSteps,
        question: AppStrings.onboardingTitles[8],
        questionSubtitle: AppStrings.onboardingSubtitles[8],
        illustrationPath: AppAssets.conditionsIllustration,
        fallbackIcon: Icons.medical_services_rounded,
        onBack: onBack,
        onContinue: onNext,
        canContinue: provider.conditions.isNotEmpty,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select all that apply',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _conditions.map((condition) {
                final selected = provider.conditions.contains(condition);
                return GestureDetector(
                  onTap: () {
                    context.read<OnboardingProvider>().toggleCondition(condition);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primarySurface
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          condition,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            // Medical disclaimer
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FitAI provides general nutritional guidance. Not a substitute for professional medical advice.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
