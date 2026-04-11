import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 10: Dietary preference — single-select chips.
class StepDietary extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepDietary({super.key, required this.onNext, required this.onBack});

  static const _preferences = AppStrings.dietaryPreferences;

  static const _emojis = ['🥩', '🌱', '🥗', '🥑', '🫒', '🌾', '🥛'];

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) => OnboardingScaffold(
        currentStep: provider.currentStep,
        totalSteps: provider.totalSteps,
        question: AppStrings.onboardingTitles[10],
        questionSubtitle: AppStrings.onboardingSubtitles[10],
        illustrationPath: AppAssets.dietaryIllustration,
        fallbackIcon: Icons.restaurant_rounded,
        onBack: onBack,
        onContinue: onNext,
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_preferences.length, (index) {
            final pref = _preferences[index];
            final selected = provider.dietaryPreference == pref;
            return GestureDetector(
              onTap: () {
                context.read<OnboardingProvider>().setDietaryPreference(pref);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primarySurface
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.shadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      index < _emojis.length ? _emojis[index] : '🍽️',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pref,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
