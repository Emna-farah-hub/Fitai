import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/press_scale.dart';

class CommitmentScreen extends StatelessWidget {
  final VoidCallback onNext;

  const CommitmentScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final name = provider.name.trim().isEmpty ? 'friend' : provider.name.trim();
    final cuisines = provider.favoriteCuisines.isEmpty
        ? 'Open to all'
        : provider.favoriteCuisines.take(2).join(', ');

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          const _CommitmentBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Final review',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Here's what I know, $name.",
                    style: GoogleFonts.nunito(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'One last look before FitAI builds your plan.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.64),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ReviewCard(
                    title: 'Goal',
                    icon: Icons.flag_rounded,
                    left: provider.primaryGoal ?? 'Feel better',
                    right: 'Target ${provider.targetWeightKg.round()} kg',
                  ),
                  const SizedBox(height: 12),
                  _ReviewCard(
                    title: 'Body & pace',
                    icon: Icons.insights_rounded,
                    left: provider.activityLevel,
                    right: provider.resultPaceLabel,
                  ),
                  const SizedBox(height: 12),
                  _ReviewCard(
                    title: 'Food profile',
                    icon: Icons.local_dining_rounded,
                    left: provider.dietaryPreference,
                    right: cuisines,
                  ),
                  const Spacer(flex: 3),
                  PressScale(
                    onPressed: onNext,
                    pressedScale: 0.97,
                    invokeDelay: const Duration(milliseconds: 50),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "I'm ready - build my plan",
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'This takes about 10 seconds',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommitmentBackdrop extends StatelessWidget {
  const _CommitmentBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -20,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1616A34A),
                    Color(0x0416A34A),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: 130,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x10F2B441),
                    Color(0x03F2B441),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String left;
  final String right;

  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryLight),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ReviewValue(left)),
              const SizedBox(width: 10),
              Expanded(child: _ReviewValue(right, alignRight: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewValue extends StatelessWidget {
  final String text;
  final bool alignRight;

  const _ReviewValue(this.text, {this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white.withValues(alpha: 0.94),
        height: 1.3,
      ),
    );
  }
}
