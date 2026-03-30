import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 7: Fitness level — 5 chip options from "Just starting out" to "Super powerful".
class StepFitness extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepFitness({super.key, required this.onNext, required this.onBack});

  static const _levels = AppStrings.fitnessLevels;

  static const _icons = [
    Icons.emoji_nature_outlined,
    Icons.directions_walk_outlined,
    Icons.directions_run_outlined,
    Icons.local_fire_department_outlined,
    Icons.bolt_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) => OnboardingScaffold(
        currentStep: provider.currentStep,
        totalSteps: provider.totalSteps,
        question: AppStrings.onboardingTitles[7],
        questionSubtitle: AppStrings.onboardingSubtitles[7],
        onBack: onBack,
        onContinue: onNext,
        content: Column(
          children: List.generate(_levels.length, (index) {
            final level = _levels[index];
            final selected = provider.fitnessLevel == level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  context.read<OnboardingProvider>().setFitnessLevel(level);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primarySurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _icons[index],
                        color: selected ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        level,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
