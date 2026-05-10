import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'gradient_button.dart';
import 'illustration_widget.dart';

/// Shared scaffold used by every onboarding step.
/// Renders: back button, progress bar, illustration, title, subtitle, content, continue button.
class OnboardingScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String question;
  final String? questionSubtitle;
  final Widget content;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final bool isLoading;
  final bool canContinue;
  final String continueLabel;
  final String? illustrationPath;
  final IconData fallbackIcon;

  const OnboardingScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.question,
    this.questionSubtitle,
    required this.content,
    this.onContinue,
    this.onBack,
    this.isLoading = false,
    this.canContinue = true,
    this.continueLabel = 'Continue',
    this.illustrationPath,
    this.fallbackIcon = Icons.auto_awesome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + progress
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (currentStep > 0)
                      GestureDetector(
                        onTap: onBack,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                    const SizedBox(width: 12),
                    // Segmented pill progress bar
                    Expanded(
                      child: Row(
                        children: [
                          for (int i = 0; i < totalSteps; i++) ...[
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i < currentStep
                                      ? AppColors.primary
                                      : i == currentStep
                                      ? AppColors.primary.withValues(alpha: 0.4)
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            if (i < totalSteps - 1) const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Illustration
                      if (illustrationPath != null)
                        IllustrationWidget(
                          assetPath: illustrationPath!,
                          fallbackIcon: fallbackIcon,
                          height: 160,
                        ).animate().fadeIn(duration: 400.ms),

                      if (illustrationPath != null) const SizedBox(height: 16),

                      // Title
                      Text(
                            question,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms)
                          .slideY(begin: 0.1, end: 0),

                      if (questionSubtitle != null) ...[
                        const SizedBox(height: 12),
                        Text(
                              questionSubtitle!,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 150.ms)
                            .slideY(begin: 0.08, end: 0),
                      ],

                      const SizedBox(height: 24),

                      // Step-specific input content
                      content.animate().fadeIn(duration: 400.ms, delay: 200.ms),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom continue button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: GradientButton(
                  label: continueLabel,
                  onPressed: canContinue ? onContinue : null,
                  isLoading: isLoading,
                  trailingIcon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
