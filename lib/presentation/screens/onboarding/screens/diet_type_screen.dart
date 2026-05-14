import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/why_banner.dart';

class DietTypeScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const DietTypeScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_DietOption> _options = [
    _DietOption(icon: Icons.restaurant, title: 'I eat everything'),
    _DietOption(
      icon: Icons.spa,
      title: 'Vegetarian',
      subtitle: 'No meat or fish',
    ),
    _DietOption(
      icon: Icons.eco,
      title: 'Vegan',
      subtitle: 'No animal products',
    ),
    _DietOption(
      icon: Icons.set_meal,
      title: 'Pescatarian',
      subtitle: 'Fish but no meat',
    ),
    _DietOption(
      icon: Icons.more_horiz,
      title: 'Other',
      subtitle: "I'll specify later",
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
                _Title('How do you eat?'),
                const SizedBox(height: 16),
                WhyBanner(
                      explanation:
                          'This ensures every recipe fits your dietary pattern.',
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
                  _DietCard(
                        option: _options[i],
                        selected:
                            provider.dietaryPreference == _options[i].title,
                        accentColor: accentColor,
                        onTap: () =>
                            provider.setDietaryPreference(_options[i].title),
                      )
                      .animate()
                      .fadeIn(
                        duration: 280.ms,
                        delay: Duration(milliseconds: 180 + i * 80),
                      )
                      .slideY(
                        begin: 22 / 70,
                        end: 0,
                        duration: 280.ms,
                        delay: Duration(milliseconds: 180 + i * 80),
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

class _DietOption {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _DietOption({required this.icon, required this.title, this.subtitle});
}

class _DietCard extends StatelessWidget {
  final _DietOption option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DietCard({
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
          color: selected ? accentColor.withValues(alpha: 0.14) : Colors.white,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.24)
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                option.icon,
                size: 22,
                color: selected ? AppColors.primaryDark : AppColors.textMuted,
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
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

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
