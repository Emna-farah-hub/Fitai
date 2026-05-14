import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/why_banner.dart';

class ActivityLevelScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const ActivityLevelScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_ActivityOption> _options = [
    _ActivityOption(
      icon: Icons.weekend,
      title: 'Sedentary',
      value: 'Sedentary',
      description: 'Desk job, very little movement',
    ),
    _ActivityOption(
      icon: Icons.directions_walk,
      title: 'Lightly active',
      value: 'Lightly Active',
      description: 'Walk sometimes, exercise 1-2x/week',
    ),
    _ActivityOption(
      icon: Icons.directions_run,
      title: 'Moderately active',
      value: 'Moderately Active',
      description: 'Exercise 3-5 days/week',
    ),
    _ActivityOption(
      icon: Icons.fitness_center,
      title: 'Very active',
      value: 'Very Active',
      description: 'Hard training 6-7 days/week',
    ),
    _ActivityOption(
      icon: Icons.local_fire_department,
      title: 'Athlete',
      value: 'Athlete',
      description: 'Physical job + daily training',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return OnboardingQuestionScaffold(
          backgroundColor: paleColor,
          currentSection: currentSection,
          progressInSection: progressInSection,
          accentColor: accentColor,
          onBack: onBack,
          onNext: onNext,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuestionTitle('How active are you on a typical day?'),
                const SizedBox(height: 16),
                WhyBanner(
                      explanation:
                          'Activity level directly affects how many calories your body burns. We use this to set your daily target.',
                      accentColor: accentColor,
                    )
                    .animate()
                    .fadeIn(duration: 280.ms, delay: 100.ms)
                    .slideY(
                      begin: 20 / 60,
                      end: 0,
                      duration: 280.ms,
                      delay: 100.ms,
                    ),
                const SizedBox(height: 20),
                for (int i = 0; i < _options.length; i++) ...[
                  _ActivityCard(
                        option: _options[i],
                        selected: provider.activityLevel == _options[i].value,
                        accentColor: accentColor,
                        onTap: () =>
                            provider.setActivityLevel(_options[i].value),
                      )
                      .animate()
                      .fadeIn(
                        duration: 280.ms,
                        delay: Duration(milliseconds: 200 + i * 80),
                      )
                      .slideY(
                        begin: 24 / 76,
                        end: 0,
                        duration: 280.ms,
                        delay: Duration(milliseconds: 200 + i * 80),
                      ),
                  if (i < _options.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityOption {
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const _ActivityOption({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });
}

class _ActivityCard extends StatelessWidget {
  final _ActivityOption option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.option,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.18)
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                option.icon,
                size: 22,
                color: selected ? accentColor : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  final String text;

  const _QuestionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 24 / 26, end: 0, duration: 280.ms);
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _PressScale({required this.child, required this.onPressed});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    await _controller.forward();
    if (!mounted) return;
    _controller.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
