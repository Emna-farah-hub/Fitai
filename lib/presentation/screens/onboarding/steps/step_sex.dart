import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 5: Biological sex — Male / Female selection cards.
class StepSex extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepSex({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) => OnboardingScaffold(
        currentStep: provider.currentStep,
        totalSteps: provider.totalSteps,
        question: AppStrings.onboardingTitles[5],
        questionSubtitle: AppStrings.onboardingSubtitles[5],
        illustrationPath: AppAssets.sexIllustration,
        fallbackIcon: Icons.people_rounded,
        onBack: onBack,
        onContinue: onNext,
        content: Row(
          children: [
            Expanded(
              child: _SexCard(
                label: 'Male',
                icon: Icons.male_rounded,
                selected: provider.sex == 'male',
                onTap: () {
                  context.read<OnboardingProvider>().setSex('male');
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SexCard(
                label: 'Female',
                icon: Icons.female_rounded,
                selected: provider.sex == 'female',
                onTap: () {
                  context.read<OnboardingProvider>().setSex('female');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SexCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SexCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 52,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
