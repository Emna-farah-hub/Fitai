import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/press_scale.dart';

class CookingScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const CookingScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_CookingOption> _skills = [
    _CookingOption(
      title: 'I barely cook',
      subtitle: 'Give me the simplest recipes',
    ),
    _CookingOption(
      title: 'I can follow a recipe',
      subtitle: 'Comfortable in the kitchen',
    ),
    _CookingOption(title: 'I love cooking', subtitle: 'Challenge me'),
  ];

  static const List<String> _times = ['Under 15 min', '15-30 min', '30+ min'];

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final hasSkill = provider.cookingSkill != null;

        return OnboardingQuestionScaffold(
          backgroundColor: paleColor,
          currentSection: currentSection,
          progressInSection: progressInSection,
          accentColor: accentColor,
          onBack: onBack,
          onNext: onNext,
          isNextEnabled: provider.cookingSkill != null,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'How would you describe your cooking?',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 280.ms)
                    .slideY(begin: 24 / 26, end: 0, duration: 280.ms),
                const SizedBox(height: 24),
                for (int i = 0; i < _skills.length; i++) ...[
                  _CookingCard(
                        option: _skills[i],
                        selected: provider.cookingSkill == _skills[i].title,
                        accentColor: accentColor,
                        onTap: () => provider.setCookingSkill(_skills[i].title),
                      )
                      .animate()
                      .fadeIn(
                        duration: 280.ms,
                        delay: Duration(milliseconds: 150 + i * 90),
                      )
                      .slideY(
                        begin: 22 / 82,
                        end: 0,
                        duration: 280.ms,
                        delay: Duration(milliseconds: 150 + i * 90),
                      ),
                  if (i < _skills.length - 1) const SizedBox(height: 10),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: hasSkill
                      ? Padding(
                          padding: const EdgeInsets.only(top: 26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How much time per meal?',
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  for (final time in _times) ...[
                                    Expanded(
                                      child: _TimePill(
                                        label: time,
                                        selected: provider.cookingTime == time,
                                        accentColor: accentColor,
                                        onTap: () =>
                                            provider.setCookingTime(time),
                                      ),
                                    ),
                                    if (time != _times.last)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ],
                          ).animate().fadeIn(duration: 180.ms),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CookingOption {
  final String title;
  final String subtitle;

  const _CookingOption({required this.title, required this.subtitle});
}

class _CookingCard extends StatelessWidget {
  final _CookingOption option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _CookingCard({
    required this.option,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onPressed: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    option.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.elasticOut,
              child: Icon(Icons.check_circle, color: accentColor, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TimePill({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onPressed: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 2,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
