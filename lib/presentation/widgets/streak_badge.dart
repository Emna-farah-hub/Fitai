import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/streak_service.dart';

/// Pill widget that shows the user's consecutive-day meal-logging streak.
///
/// Listens to `users/{uid}.streakDays` in real time so the badge updates the
/// moment the first meal of the day is logged. Renders as a compact orange
/// pill with a flame icon — designed to live in the dashboard header.
class StreakBadge extends StatelessWidget {
  final String uid;

  const StreakBadge({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: StreakService().streakStream(uid),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;
        if (streak <= 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.amberSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.amberDark.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: AppColors.amberDark,
              ),
              const SizedBox(width: 4),
              Text(
                '$streak day${streak == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amberDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
