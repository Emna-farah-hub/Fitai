import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Horizontal pill-shaped progress bar for the onboarding flow.
class OnboardingProgressBar extends StatelessWidget {
  final int totalSections;
  final int currentSection;
  final double progressInSection;
  final Color accentColor;

  const OnboardingProgressBar({
    super.key,
    this.totalSections = 6,
    required this.currentSection,
    required this.progressInSection,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    const futureColor = AppColors.border;
    final clampedProgress = progressInSection.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (int i = 0; i < totalSections; i++) ...[
              Expanded(
                child: _ProgressSegment(
                  state: i + 1 < currentSection
                      ? _SegmentState.completed
                      : i + 1 == currentSection
                      ? _SegmentState.current
                      : _SegmentState.future,
                  progress: clampedProgress,
                  accentColor: accentColor,
                  futureColor: futureColor,
                ),
              ),
              if (i < totalSections - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SegmentState { completed, current, future }

class _ProgressSegment extends StatelessWidget {
  final _SegmentState state;
  final double progress;
  final Color accentColor;
  final Color futureColor;

  const _ProgressSegment({
    required this.state,
    required this.progress,
    required this.accentColor,
    required this.futureColor,
  });

  @override
  Widget build(BuildContext context) {
    final completedTrack = Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [accentColor.withValues(alpha: 0.72), accentColor],
        ),
      ),
    );

    if (state == _SegmentState.completed) return completedTrack;

    if (state == _SegmentState.future) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: futureColor.withValues(alpha: 0.95),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: futureColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  final width = constraints.maxWidth * value;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      width: width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.32),
                            accentColor.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
