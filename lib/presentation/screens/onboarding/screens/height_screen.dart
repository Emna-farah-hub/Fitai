import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/body_ruler_picker.dart';
import '../../../widgets/onboarding_question_scaffold.dart';
import '../../../widgets/press_scale.dart';

class HeightScreen extends StatefulWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const HeightScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  bool _useMetric = true;
  int _lastHapticHeight = 170;

  String _heightLabel(double cm) {
    if (_useMetric) return cm.round().toString();
    final totalInches = (cm / 2.54).round();
    return "${totalInches ~/ 12}'${totalInches % 12}";
  }

  String _rulerLabel(int cm) {
    if (_useMetric) return '$cm';
    final totalInches = (cm / 2.54).round();
    return "${totalInches ~/ 12}'${totalInches % 12}";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return OnboardingQuestionScaffold(
          backgroundColor: widget.paleColor,
          currentSection: widget.currentSection,
          progressInSection: widget.progressInSection,
          accentColor: widget.accentColor,
          onBack: widget.onBack,
          onNext: widget.onNext,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'How tall are you?',
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
                      'We use this with your age and weight to personalize your calorie target.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 280.ms, delay: 100.ms)
                    .slideY(
                      begin: 20 / 40,
                      end: 0,
                      duration: 280.ms,
                      delay: 100.ms,
                    ),
                const SizedBox(height: 20),
                Center(
                      child: _UnitToggle(
                        firstLabel: 'cm',
                        secondLabel: 'ft/in',
                        firstSelected: _useMetric,
                        accentColor: AppColors.tealDark,
                        onChanged: (value) => setState(() {
                          _useMetric = value;
                          _lastHapticHeight = provider.heightCm.round();
                        }),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 240.ms, delay: 160.ms)
                    .slideY(
                      begin: 14 / 44,
                      end: 0,
                      duration: 240.ms,
                      delay: 160.ms,
                    ),
                const SizedBox(height: 26),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Row(
                      key: ValueKey(
                        '${_useMetric}_${provider.heightCm.round()}',
                      ),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _heightLabel(provider.heightCm),
                          style: GoogleFonts.nunito(
                            fontSize: 62,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tealDark,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _useMetric ? 'cm' : 'ft/in',
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _HeightSelectionStage(
                      value: provider.heightCm,
                      accentColor: widget.accentColor,
                      labelFormatter: _rulerLabel,
                      onChanged: (value) {
                        final rounded = value.round();
                        if ((rounded - _lastHapticHeight).abs() >= 2) {
                          _lastHapticHeight = rounded;
                          HapticFeedback.selectionClick();
                        }
                        provider.setHeight(value);
                      },
                    )
                    .animate()
                    .fadeIn(duration: 320.ms, delay: 240.ms)
                    .slideY(
                      begin: 20 / 500,
                      end: 0,
                      duration: 320.ms,
                      delay: 240.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.straighten_rounded,
                        color: widget.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Drag the ruler until the line reaches the top of the silhouette.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeightSelectionStage extends StatelessWidget {
  final double value;
  final Color accentColor;
  final String Function(int tick) labelFormatter;
  final ValueChanged<double> onChanged;

  const _HeightSelectionStage({
    required this.value,
    required this.accentColor,
    required this.labelFormatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const stageHeight = 500.0;
    const rulerHeight = 450.0;
    const indicatorFraction = 0.32;
    const headAnchorFraction = 0.16;
    const visibleBottomFraction = 0.974;

    return SizedBox(
      height: stageHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final rulerWidth = (availableWidth * 0.37).clamp(142.0, 154.0);
          const gap = 2.0;
          final normalized = ((value - 140) / 70).clamp(0.0, 1.0);
          final figureHeight = 320 + (normalized * 70);
          final figureWidth = figureHeight * 0.64;
          const rulerTop = 12.0;
          final markerY = rulerTop + (rulerHeight * indicatorFraction);
          final figureTop = markerY - (figureHeight * headAnchorFraction);
          final feetY = figureTop + (figureHeight * visibleBottomFraction);
          final pairWidth = figureWidth + gap + rulerWidth;
          final pairLeft = math.max(0.0, (availableWidth - pairWidth) / 2);
          final figureLeft = pairLeft;
          final figureCenterX = figureLeft + (figureWidth / 2);
          final rulerLeft = figureLeft + figureWidth + gap;
          final connectorStartX = figureLeft + (figureWidth * 0.78);
          final connectorEndX = rulerLeft + 20;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: figureCenterX - (figureHeight * 0.30),
                top: figureTop + (figureHeight * 0.10),
                child: IgnorePointer(
                  child: Container(
                    width: figureHeight * 0.60,
                    height: figureHeight * 0.60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0x33F2B441),
                          const Color(0x08F2B441),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: figureCenterX - (figureHeight * 0.18),
                top: figureTop + (figureHeight * 0.22),
                child: IgnorePointer(
                  child: Container(
                    width: figureHeight * 0.36,
                    height: figureHeight * 0.62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x1FF2B441),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: figureLeft - 10,
                right: 0,
                top: markerY - 1,
                child: IgnorePointer(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0),
                          accentColor.withValues(alpha: 0.18),
                          accentColor.withValues(alpha: 0.26),
                          accentColor.withValues(alpha: 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: figureLeft,
                top: figureTop,
                child: _BodyHeightSilhouette(height: figureHeight),
              ),
              Positioned(
                left: connectorStartX,
                top: markerY - 1.5,
                child: IgnorePointer(
                  child: Container(
                    width: math.max(0, connectorEndX - connectorStartX),
                    height: 3,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: figureCenterX - 40,
                top: feetY + 8,
                child: IgnorePointer(
                  child: Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.tealDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: rulerLeft,
                top: rulerTop,
                child: VerticalHeightRuler(
                  value: value,
                  min: 140,
                  max: 210,
                  indicatorFraction: indicatorFraction,
                  width: rulerWidth,
                  height: rulerHeight,
                  pixelsPerUnit: 11.2,
                  accentColor: accentColor,
                  labelFormatter: labelFormatter,
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BodyHeightSilhouette extends StatelessWidget {
  final double height;

  const _BodyHeightSilhouette({required this.height});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: height * 0.72,
        height: height,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: 0.70,
            child: Opacity(
              opacity: 0.98,
              child: Image.asset(
                'assets/illustrations/height_silhouette.png',
                height: height,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String firstLabel;
  final String secondLabel;
  final bool firstSelected;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _UnitToggle({
    required this.firstLabel,
    required this.secondLabel,
    required this.firstSelected,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UnitButton(
          label: firstLabel,
          selected: firstSelected,
          accentColor: accentColor,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 8),
        _UnitButton(
          label: secondLabel,
          selected: !firstSelected,
          accentColor: accentColor,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _UnitButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _UnitButton({
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: 1.5,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
