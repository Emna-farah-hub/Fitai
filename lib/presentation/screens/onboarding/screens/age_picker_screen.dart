import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/why_banner.dart';

class AgePickerScreen extends StatefulWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const AgePickerScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  @override
  State<AgePickerScreen> createState() => _AgePickerScreenState();
}

class _AgePickerScreenState extends State<AgePickerScreen> {
  static const int _minAge = 14;
  static const int _maxAge = 90;

  late final FixedExtentScrollController _controller;
  late int _selectedAge;

  @override
  void initState() {
    super.initState();
    final providerAge = context.read<OnboardingProvider>().age;
    _selectedAge = providerAge.clamp(_minAge, _maxAge);
    _controller = FixedExtentScrollController(
      initialItem: _selectedAge - _minAge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAge(int index) {
    final age = _minAge + index;
    HapticFeedback.selectionClick();
    setState(() => _selectedAge = age);
    context.read<OnboardingProvider>().setAge(age);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingQuestionScaffold(
      backgroundColor: widget.paleColor,
      currentSection: widget.currentSection,
      progressInSection: widget.progressInSection,
      accentColor: widget.accentColor,
      onBack: widget.onBack,
      onNext: widget.onNext,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height - 180,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                    'How old are you?',
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
              const SizedBox(height: 16),
              WhyBanner(
                    explanation:
                        'Your age affects your metabolic rate. Younger bodies burn calories differently than older ones.',
                    accentColor: widget.accentColor,
                  )
                  .animate()
                  .fadeIn(duration: 280.ms, delay: 100.ms)
                  .slideY(
                    begin: 20 / 60,
                    end: 0,
                    duration: 280.ms,
                    delay: 100.ms,
                  ),
              const SizedBox(height: 38),
              SizedBox(
                    height: 320,
                    child: ListWheelScrollView.useDelegate(
                      controller: _controller,
                      itemExtent: 64,
                      diameterRatio: 2.0,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: _setAge,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _maxAge - _minAge + 1,
                        builder: (context, index) {
                          final age = _minAge + index;
                          final distance = (age - _selectedAge).abs();
                          final selected = distance == 0;
                          final adjacent = distance == 1;

                          return Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: selected ? 280 : 220,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: selected
                                  ? BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          offset: const Offset(0, 2),
                                          blurRadius: 8,
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                              child: Text(
                                '$age',
                                style: GoogleFonts.nunito(
                                  fontSize: selected
                                      ? 52
                                      : adjacent
                                      ? 40
                                      : 32,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : adjacent
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected
                                      ? AppColors.textPrimary
                                      : adjacent
                                      ? AppColors.textMuted
                                      : AppColors.border,
                                  height: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 280.ms, delay: 200.ms)
                  .slideY(
                    begin: 24 / 320,
                    end: 0,
                    duration: 280.ms,
                    delay: 200.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
