import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/illustration_widget.dart';

class OnboardingBridgeScreen extends StatefulWidget {
  const OnboardingBridgeScreen({
    super.key,
    required this.firstName,
    required this.onContinue,
  });

  final String firstName;
  final VoidCallback onContinue;

  @override
  State<OnboardingBridgeScreen> createState() => _OnboardingBridgeScreenState();
}

class _OnboardingBridgeScreenState extends State<OnboardingBridgeScreen> {
  Timer? _autoAdvance;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _autoAdvance = Timer(const Duration(milliseconds: 2500), _advance);
  }

  void _advance() {
    if (_completed) return;
    _completed = true;
    widget.onContinue();
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                const IllustrationWidget(
                      assetPath: AppAssets.successIllustration,
                      fallbackIcon: Icons.check_circle_outline_rounded,
                      height: 200,
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                      duration: 500.ms,
                    ),
                const SizedBox(height: 28),
                Text(
                      'Welcome, ${widget.firstName}!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 12),
                Text(
                      "Your profile is ready. Now let's discover foods you love →",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 400.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(active: true, delayMs: 600),
                    const SizedBox(width: 8),
                    _dot(active: false, delayMs: 700),
                    const SizedBox(width: 8),
                    _dot(active: false, delayMs: 800),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot({required bool active, required int delayMs}) {
    return Container(
      width: active ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: delayMs.ms);
  }
}
