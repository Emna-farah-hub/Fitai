import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';

class StrugglesScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const StrugglesScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_StruggleOption> _options = [
    _StruggleOption(icon: Icons.event_busy, label: 'Staying consistent'),
    _StruggleOption(icon: Icons.nightlight, label: 'Late-night snacking'),
    _StruggleOption(icon: Icons.help_outline, label: 'Not knowing what to eat'),
    _StruggleOption(icon: Icons.storefront, label: 'Eating out too much'),
    _StruggleOption(icon: Icons.timer_off, label: 'Skipping meals'),
    _StruggleOption(icon: Icons.mood_bad, label: 'Lack of motivation'),
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
                Text(
                      "What's been your biggest challenge?",
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
                const SizedBox(height: 8),
                Text(
                  'Select all that apply',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(duration: 280.ms, delay: 100.ms),
                const SizedBox(height: 22),
                for (int i = 0; i < _options.length; i++) ...[
                  _StruggleCard(
                        option: _options[i],
                        selected: provider.struggles.contains(
                          _options[i].label,
                        ),
                        onTap: () => provider.toggleStruggle(_options[i].label),
                      )
                      .animate()
                      .fadeIn(
                        duration: 280.ms,
                        delay: Duration(milliseconds: 160 + i * 70),
                      )
                      .slideY(
                        begin: 24 / 64,
                        end: 0,
                        duration: 280.ms,
                        delay: Duration(milliseconds: 160 + i * 70),
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

class _StruggleOption {
  final IconData icon;
  final String label;

  const _StruggleOption({required this.icon, required this.label});
}

class _StruggleCard extends StatelessWidget {
  final _StruggleOption option;
  final bool selected;
  final VoidCallback onTap;

  const _StruggleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  static const Color _green = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _green.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _green : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? _green.withValues(alpha: 0.18)
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.icon,
                size: 21,
                color: selected ? _green : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.elasticOut,
              child: const Icon(Icons.check_circle, color: _green, size: 22),
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
