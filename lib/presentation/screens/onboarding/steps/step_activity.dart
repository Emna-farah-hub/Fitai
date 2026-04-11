import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 6: Activity level — 4 option cards with icon and description.
class StepActivity extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepActivity({super.key, required this.onNext, required this.onBack});

  static const _options = [
    _ActivityOption(
      label: 'Sedentary',
      description: 'Little or no exercise',
      icon: Icons.weekend_outlined,
      multiplier: '×1.2',
    ),
    _ActivityOption(
      label: 'Lightly Active',
      description: 'Light exercise 1–3 days/week',
      icon: Icons.directions_walk_outlined,
      multiplier: '×1.375',
    ),
    _ActivityOption(
      label: 'Moderately Active',
      description: 'Moderate exercise 3–5 days/week',
      icon: Icons.directions_run_outlined,
      multiplier: '×1.55',
    ),
    _ActivityOption(
      label: 'Very Active',
      description: 'Hard exercise 6–7 days/week',
      icon: Icons.fitness_center_outlined,
      multiplier: '×1.725',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) => OnboardingScaffold(
        currentStep: provider.currentStep,
        totalSteps: provider.totalSteps,
        question: AppStrings.onboardingTitles[6],
        questionSubtitle: AppStrings.onboardingSubtitles[6],
        illustrationPath: AppAssets.activityIllustration,
        fallbackIcon: Icons.directions_run_rounded,
        onBack: onBack,
        onContinue: onNext,
        content: Column(
          children: _options.map((option) {
            final selected = provider.activityLevel == option.label;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  context.read<OnboardingProvider>().setActivityLevel(option.label);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primarySurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          option.icon,
                          color: selected ? Colors.white : AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              option.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        option.multiplier,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ActivityOption {
  final String label;
  final String description;
  final IconData icon;
  final String multiplier;

  const _ActivityOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.multiplier,
  });
}
