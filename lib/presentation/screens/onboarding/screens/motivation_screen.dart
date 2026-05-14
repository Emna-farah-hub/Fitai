import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/why_banner.dart';

class MotivationScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const MotivationScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<String> _options = [
    'Feel better in my body',
    'Build self-confidence',
    'Improve my health',
    'Have more energy',
    'Get in shape',
  ];

  String _headline(String? goal) {
    if (goal == null) return 'Why do you want this?';
    return 'Why do you want to ${goal.toLowerCase()}?';
  }

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
          isNextEnabled: provider.goalMotivation != null,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      _headline(provider.primaryGoal),
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 280.ms)
                    .slideY(begin: 24 / 26, end: 0, duration: 280.ms),
                const SizedBox(height: 16),
                WhyBanner(
                      explanation:
                          'Understanding your motivation helps us send the right encouragement when it gets hard.',
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
                  _MotivationCard(
                        label: _options[i],
                        selected: provider.goalMotivation == _options[i],
                        accentColor: accentColor,
                        onTap: () => provider.setGoalMotivation(_options[i]),
                      )
                      .animate()
                      .fadeIn(
                        duration: 280.ms,
                        delay: Duration(milliseconds: 200 + i * 100),
                      )
                      .slideY(
                        begin: 24 / 60,
                        end: 0,
                        duration: 280.ms,
                        delay: Duration(milliseconds: 200 + i * 100),
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

class _MotivationCard extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _MotivationCard({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const animDuration = Duration(milliseconds: 150);
    return _PressScale(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: animDuration,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: animDuration,
              curve: Curves.easeInOut,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? accentColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accentColor : AppColors.border,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
