import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/illustration_widget.dart';

/// Step 0: Welcome screen — illustration, logo, tagline, feature highlights, "Get Started" CTA.
class StepWelcome extends StatelessWidget {
  final VoidCallback onNext;

  const StepWelcome({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 1),
                // Illustration
                IllustrationWidget(
                  assetPath: AppAssets.welcomeIllustration,
                  fallbackIcon: Icons.favorite_rounded,
                  height: 220,
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 24),
                // App name: "Fit" in green + "AI" in dark
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Fit',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -1,
                        ),
                      ),
                      TextSpan(
                        text: 'AI',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  'Your AI-powered nutrition coach',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 300.ms),
                const SizedBox(height: 32),
                // Feature cards
                _FeatureCard(
                  icon: Icons.calculate_outlined,
                  title: 'Personalized calorie goals',
                  subtitle: 'Based on your body & lifestyle',
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Diabetes-friendly plans',
                  subtitle: 'Track glycemic index with ease',
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI coach powered by Gemini',
                  subtitle: 'Smart meal suggestions & guidance',
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideX(begin: -0.05, end: 0),
                const Spacer(flex: 2),
                GradientButton(
                  label: 'Get Started',
                  onPressed: onNext,
                  trailingIcon: Icons.arrow_forward_rounded,
                ).animate().fadeIn(duration: 400.ms, delay: 700.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                Text(
                  'Takes only 2 minutes to set up',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
