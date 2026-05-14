import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';

class ReferralScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const ReferralScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_ReferralOption> _gridOptions = [
    _ReferralOption(icon: Icons.people, label: 'Friend or family'),
    _ReferralOption(icon: Icons.phone_android, label: 'Social media'),
    _ReferralOption(icon: Icons.medical_services, label: 'Health professional'),
    _ReferralOption(icon: Icons.store, label: 'App Store'),
  ];
  static const _ReferralOption _otherOption = _ReferralOption(
    icon: Icons.more_horiz,
    label: 'Something else',
  );

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
          isNextEnabled: provider.referralSource != null,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'What brought you to FitAI?',
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
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _gridOptions.length,
                  itemBuilder: (context, index) {
                    final option = _gridOptions[index];
                    final selected = provider.referralSource == option.label;
                    return _ReferralCard(
                          option: option,
                          selected: selected,
                          accentColor: accentColor,
                          onTap: () => provider.setReferralSource(option.label),
                        )
                        .animate()
                        .fadeIn(
                          duration: 280.ms,
                          delay: Duration(milliseconds: 200 + index * 100),
                        )
                        .slideY(
                          begin: 24 / 100,
                          end: 0,
                          duration: 280.ms,
                          delay: Duration(milliseconds: 200 + index * 100),
                        );
                  },
                ),
                const SizedBox(height: 10),
                _ReferralCard(
                      option: _otherOption,
                      selected: provider.referralSource == _otherOption.label,
                      accentColor: accentColor,
                      onTap: () =>
                          provider.setReferralSource(_otherOption.label),
                      fullWidth: true,
                    )
                    .animate()
                    .fadeIn(
                      duration: 280.ms,
                      delay: const Duration(milliseconds: 600),
                    )
                    .slideY(
                      begin: 24 / 100,
                      end: 0,
                      duration: 280.ms,
                      delay: const Duration(milliseconds: 600),
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

class _ReferralOption {
  final IconData icon;
  final String label;
  const _ReferralOption({required this.icon, required this.label});
}

class _ReferralCard extends StatelessWidget {
  final _ReferralOption option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ReferralCard({
    required this.option,
    required this.selected,
    required this.accentColor,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    const animDuration = Duration(milliseconds: 150);
    final body = AnimatedContainer(
      duration: animDuration,
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? accentColor.withValues(alpha: 0.12) : Colors.white,
        border: Border.all(
          color: selected ? accentColor : AppColors.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          fullWidth
              ? Row(
                  children: [
                    _IconBadge(
                      icon: option.icon,
                      selected: selected,
                      accentColor: accentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.label,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconBadge(
                      icon: option.icon,
                      selected: selected,
                      accentColor: accentColor,
                    ),
                    Text(
                      option.label,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
          if (selected)
            Positioned(
              top: -4,
              right: -4,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.elasticOut,
                builder: (context, t, _) => Transform.scale(
                  scale: t,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return _PressScale(onPressed: onTap, child: body);
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color accentColor;

  const _IconBadge({
    required this.icon,
    required this.selected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selected
            ? accentColor.withValues(alpha: 0.2)
            : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? Colors.white : AppColors.primary,
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
