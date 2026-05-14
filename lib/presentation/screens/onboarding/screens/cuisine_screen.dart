import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/press_scale.dart';

class CuisineScreen extends StatelessWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const CuisineScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  static const List<_CuisineOption> _options = [
    _CuisineOption(name: 'Tunisian', mark: '🇹🇳'),
    _CuisineOption(name: 'Mediterranean', mark: '🫒'),
    _CuisineOption(name: 'Middle Eastern', mark: '🥙'),
    _CuisineOption(name: 'French', mark: '🥖'),
    _CuisineOption(name: 'Italian', mark: '🍝'),
    _CuisineOption(name: 'Asian', mark: '🍜'),
    _CuisineOption(name: 'Mexican', mark: '🌮'),
    _CuisineOption(name: 'Indian', mark: '🍛'),
    _CuisineOption(name: 'International', mark: '🌍'),
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
                      'What cuisines do you love?',
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
                  "We'll prioritize these in your meal plan.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ).animate().fadeIn(duration: 280.ms, delay: 100.ms),
                const SizedBox(height: 22),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return _CuisineCard(
                          option: option,
                          selected: provider.favoriteCuisines.contains(
                            option.name,
                          ),
                          accentColor: accentColor,
                          highlighted: option.name == 'Tunisian',
                          onTap: () =>
                              provider.toggleFavoriteCuisine(option.name),
                        )
                        .animate()
                        .fadeIn(
                          duration: 260.ms,
                          delay: Duration(milliseconds: 160 + index * 50),
                        )
                        .slideY(
                          begin: 20 / 100,
                          end: 0,
                          duration: 260.ms,
                          delay: Duration(milliseconds: 160 + index * 50),
                        );
                  },
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

class _CuisineOption {
  final String name;
  final String mark;

  const _CuisineOption({required this.name, required this.mark});
}

class _CuisineCard extends StatelessWidget {
  final _CuisineOption option;
  final bool selected;
  final bool highlighted;
  final Color accentColor;
  final VoidCallback onTap;

  const _CuisineCard({
    required this.option,
    required this.selected,
    required this.highlighted,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected || highlighted
        ? accentColor
        : AppColors.border;

    return PressScale(
      onPressed: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor.withValues(
              alpha: highlighted && !selected ? 0.55 : 1,
            ),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(option.mark, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      option.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 7,
                right: 7,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.elasticOut,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
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
