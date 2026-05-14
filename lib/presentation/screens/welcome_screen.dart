import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../widgets/fitai_plate_logo.dart';

/// Sage-green welcome screen shown after the splash, before login/register.
/// Continuous background color from the splash screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _bg = AppColors.backgroundAlt;
  static const Color _dark = AppColors.textPrimary;
  static const Color _brand = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const FitAiPlateLogo(size: 92, float: true).animate().scale(
                duration: 600.ms,
                begin: const Offset(0.3, 0.3),
                end: const Offset(1.0, 1.0),
                curve: Curves.elasticOut,
              ),
              const SizedBox(height: 28),
              Text(
                    'FitAI',
                    style: GoogleFonts.nunito(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                      height: 1,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(
                    begin: 24 / 46,
                    end: 0,
                    duration: 400.ms,
                    delay: 200.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 12),
              Text(
                    'Eat smart. Live well.',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(
                    begin: 24 / 22,
                    end: 0,
                    duration: 400.ms,
                    delay: 300.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered personal nutrition coach',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: _dark.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms),
              const Spacer(flex: 4),
              SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      shadowColor: AppColors.cardShadow,
                      elevation: 8,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () => context.go('/register'),
                        child: Center(
                          child: Text(
                            'Start Now',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _brand,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 600.ms)
                  .slideY(
                    begin: 60 / 56,
                    end: 0,
                    duration: 500.ms,
                    delay: 600.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 18),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go('/login'),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: _dark.withValues(alpha: 0.7),
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign In',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _dark.withValues(alpha: 0.9),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 800.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
