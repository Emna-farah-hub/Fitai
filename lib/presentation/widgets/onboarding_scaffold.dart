import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'chat_bubble.dart';
import 'gradient_button.dart';

/// Shared scaffold used by every onboarding step.
/// Renders: back button, progress bar, chat bubble, content area, continue button.
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            border: Border.all(color: AppColors.border),
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
                    // Progress bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Step ${currentStep + 1} of $totalSteps',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${((currentStep + 1) / totalSteps * 100).round()}%',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (currentStep + 1) / totalSteps,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI chat bubble with the question
                      ChatBubble(
                        message: question,
                        subtitle: questionSubtitle,
                      ),
                      const SizedBox(height: 28),
                      // Step-specific input content
                      content,
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
