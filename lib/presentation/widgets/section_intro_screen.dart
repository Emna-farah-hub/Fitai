import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'press_scale.dart';

/// Full-screen divider shown before each group of onboarding questions.
class SectionIntroScreen extends StatelessWidget {
  final String sectionNumber;
  final String sectionLabel;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color accentColor;
  final VoidCallback onContinue;

  const SectionIntroScreen({
    super.key,
    required this.sectionNumber,
    required this.sectionLabel,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.accentColor,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final overlay = Color.lerp(backgroundColor, Colors.black, 0.22)!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [backgroundColor, overlay],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: 86,
                  right: -48,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.22),
                          accentColor.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -44,
                  bottom: 118,
                  child: Container(
                    width: 184,
                    height: 184,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Text(
                sectionNumber,
                style: GoogleFonts.nunito(
                  fontSize: 274,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 1,
                ),
              ).animate().fadeIn(duration: 600.ms),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          sectionLabel.toUpperCase(),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.88),
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 18),
                  Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.04,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 260.ms)
                      .slideY(
                        begin: 30 / 48,
                        end: 0,
                        duration: 400.ms,
                        delay: 260.ms,
                      ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.5,
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 380.ms),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 60,
            child:
                PressScale(
                      onPressed: onContinue,
                      pressedScale: 0.97,
                      invokeDelay: const Duration(milliseconds: 50),
                      child: SizedBox(
                        height: 58,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: Center(
                            child: Text(
                              "Let's go ->",
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: backgroundColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 500.ms)
                    .slideY(
                      begin: 60 / 58,
                      end: 0,
                      duration: 500.ms,
                      delay: 500.ms,
                      curve: Curves.elasticOut,
                    ),
          ),
        ],
      ),
    );
  }
}
