import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';

class GoalSelectionScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const GoalSelectionScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_GoalOption> _options = [
    _GoalOption(
      icon: Icons.monitor_weight_outlined,
      label: 'Lose weight',
      subtitle: 'A lighter, steadier daily target',
    ),
    _GoalOption(
      icon: Icons.eco_rounded,
      label: 'Eat healthier',
      subtitle: 'Smarter meals and better balance',
    ),
    _GoalOption(
      icon: Icons.fitness_center_rounded,
      label: 'Build muscle',
      subtitle: 'Fuel and structure for strength',
    ),
    _GoalOption(
      icon: Icons.restaurant_menu_rounded,
      label: 'Try new recipes',
      subtitle: 'Fresh meal ideas you will enjoy',
    ),
    _GoalOption(
      icon: Icons.bolt_rounded,
      label: 'Boost energy',
      subtitle: 'Eat in a way that feels lighter',
    ),
    _GoalOption(
      icon: Icons.favorite_outline_rounded,
      label: 'Feel better',
      subtitle: 'A calmer relationship with food',
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
          isNextEnabled: provider.primaryGoal != null,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GoalHeroCard()
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(
                      begin: 0.16,
                      end: 0,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 24),
                Text(
                      "What's your main goal?",
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.08,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 280.ms, delay: 100.ms)
                    .slideY(
                      begin: 0.16,
                      end: 0,
                      duration: 280.ms,
                      delay: 100.ms,
                    ),
                const SizedBox(height: 10),
                Text(
                  'Your goal shapes every meal, calorie target, and coaching recommendation from here.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ).animate().fadeIn(duration: 280.ms, delay: 180.ms),
                const SizedBox(height: 22),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.94,
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    final selected = provider.primaryGoal == option.label;
                    return _GoalCard(
                          option: option,
                          selected: selected,
                          accentColor: accentColor,
                          onTap: () => provider.setPrimaryGoal(option.label),
                        )
                        .animate()
                        .fadeIn(
                          duration: 280.ms,
                          delay: Duration(milliseconds: 260 + index * 80),
                        )
                        .slideY(
                          begin: 0.18,
                          end: 0,
                          duration: 280.ms,
                          delay: Duration(milliseconds: 260 + index * 80),
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalHeroCard extends StatelessWidget {
  const _GoalHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primarySurface, AppColors.primarySoft],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.flag_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set the direction first',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This gives FitAI the context to shape the rest of your plan around what matters most.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalOption {
  final IconData icon;
  final String label;
  final String subtitle;

  const _GoalOption({
    required this.icon,
    required this.label,
    required this.subtitle,
  });
}

class _GoalCard extends StatelessWidget {
  final _GoalOption option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _GoalCard({
    required this.option,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const animDuration = Duration(milliseconds: 170);

    return _PressScale(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: animDuration,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.16),
                    accentColor.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.88),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: selected ? 2 : 1.4,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.06 : 0.03),
              blurRadius: selected ? 22 : 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: animDuration,
                  curve: Curves.easeInOut,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected
                        ? accentColor.withValues(alpha: 0.14)
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    option.icon,
                    size: 22,
                    color: selected ? accentColor : AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  option.label,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  option.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.elasticOut,
                  builder: (context, t, _) => Transform.scale(
                    scale: t,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.20),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
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
