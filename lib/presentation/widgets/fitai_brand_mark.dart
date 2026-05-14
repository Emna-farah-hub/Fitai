import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class FitAiBrandMark extends StatelessWidget {
  final double size;
  final bool playEntrance;

  const FitAiBrandMark({super.key, this.size = 86, this.playEntrance = true});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.primarySurface],
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * 0.10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.78),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.16,
            right: size * 0.16,
            child: Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'F',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: size * 0.44,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: 'A',
                      style: GoogleFonts.nunito(
                        fontSize: size * 0.18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.amberDark,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: size * 0.015),
              Container(
                width: size * 0.32,
                height: size * 0.055,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!playEntrance) return mark;

    return mark
        .animate()
        .fadeIn(duration: 360.ms)
        .scale(
          begin: const Offset(0.82, 0.82),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutBack,
        );
  }
}
