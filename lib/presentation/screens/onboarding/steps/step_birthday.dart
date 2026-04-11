import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 2: Birthday — Cupertino scroll wheel date picker.
class StepBirthday extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepBirthday({super.key, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final age = DateTime.now().year - provider.birthday.year;

        return OnboardingScaffold(
          currentStep: provider.currentStep,
          totalSteps: provider.totalSteps,
          question: AppStrings.onboardingTitles[2],
          questionSubtitle: AppStrings.onboardingSubtitles[2],
          illustrationPath: AppAssets.birthdayIllustration,
          fallbackIcon: Icons.cake_rounded,
          onBack: onBack,
          onContinue: onNext,
          content: Column(
            children: [
              // Age display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cake_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'You are $age years old',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Date picker
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: provider.birthday,
                  maximumDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                  minimumDate: DateTime(1920),
                  onDateTimeChanged: (date) {
                    context.read<OnboardingProvider>().setBirthday(date);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
