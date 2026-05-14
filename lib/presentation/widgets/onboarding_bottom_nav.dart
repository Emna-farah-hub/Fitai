import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import 'press_scale.dart';

/// Bottom navigation row used by every onboarding screen.
///
/// Renders an optional back button and an expanded primary CTA.
class OnboardingBottomNav extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;
  final bool isNextEnabled;
  final Color accentColor;

  const OnboardingBottomNav({
    super.key,
    this.onBack,
    required this.onNext,
    this.nextLabel = 'Next',
    this.isNextEnabled = true,
    this.accentColor = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    final ctaStart = Color.lerp(accentColor, AppColors.primaryDark, 0.38)!;
    final ctaEnd = Color.lerp(accentColor, AppColors.tealDark, 0.16)!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: Row(
          children: [
            if (onBack != null) ...[
              PressScale(
                onPressed: onBack,
                pressedScale: 0.97,
                haptic: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.82),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Color.lerp(
                          accentColor,
                          AppColors.textPrimary,
                          0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: PressScale(
                onPressed: isNextEnabled ? onNext : null,
                pressedScale: 0.97,
                invokeDelay: const Duration(milliseconds: 50),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isNextEnabled ? 1 : 0.48,
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [ctaStart, ctaEnd],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      nextLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
