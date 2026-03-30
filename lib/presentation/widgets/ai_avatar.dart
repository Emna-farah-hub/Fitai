import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// The AI coach avatar — a green rounded square with a Sparkles icon.
/// Appears at the top of each onboarding step as the "AI coach" persona.
class AiAvatar extends StatelessWidget {
  final double size;

  const AiAvatar({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: size * 0.46,
      ),
    );
  }
}
