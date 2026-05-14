import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'onboarding_bottom_nav.dart';
import 'onboarding_progress_bar.dart';

/// Standard chrome for an onboarding question screen.
/// Renders the section progress bar at the top and the back/next nav at
/// the bottom; [child] is rendered in between as the scrollable content.
class OnboardingQuestionScaffold extends StatelessWidget {
  final Color backgroundColor;
  final int currentSection;
  final int totalSections;
  final double progressInSection;
  final Color accentColor;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;
  final bool isNextEnabled;
  final Widget child;

  const OnboardingQuestionScaffold({
    super.key,
    required this.backgroundColor,
    required this.currentSection,
    this.totalSections = 6,
    required this.progressInSection,
    required this.accentColor,
    this.onBack,
    required this.onNext,
    this.nextLabel = 'Next',
    this.isNextEnabled = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -64,
                    right: -38,
                    child: Container(
                      width: 188,
                      height: 188,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.14),
                            accentColor.withValues(alpha: 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -32,
                    bottom: 36,
                    child: Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 10),
                OnboardingProgressBar(
                  totalSections: totalSections,
                  currentSection: currentSection,
                  progressInSection: progressInSection,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 16),
                Expanded(child: child),
                OnboardingBottomNav(
                      onBack: onBack,
                      onNext: onNext,
                      nextLabel: nextLabel,
                      isNextEnabled: isNextEnabled,
                      accentColor: accentColor,
                    )
                    .animate()
                    .fadeIn(duration: 280.ms, delay: 500.ms)
                    .slideY(
                      begin: 0.15,
                      end: 0,
                      duration: 280.ms,
                      delay: 500.ms,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
