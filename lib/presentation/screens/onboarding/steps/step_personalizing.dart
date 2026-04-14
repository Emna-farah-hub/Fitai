import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';

/// Step 11 (final): Animated "building your plan" screen.
/// Runs a timed animation then calls onComplete to save the profile and navigate.
class StepPersonalizing extends StatefulWidget {
  final VoidCallback onComplete;

  const StepPersonalizing({super.key, required this.onComplete});

  @override
  StepPersonalizingState createState() => StepPersonalizingState();
}

class StepPersonalizingState extends State<StepPersonalizing>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  bool _started = false;

  int _currentMessageIndex = 0;
  final _messages = [
    'Calculating your BMR...',
    'Computing your TDEE...',
    'Analyzing your goals...',
    'Building your meal plan...',
    'Almost there...',
    'Your plan is ready! 🎉',
  ];

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController.addListener(() {
      final newIndex = (_progressAnimation.value * (_messages.length - 1)).floor();
      if (newIndex != _currentMessageIndex && mounted) {
        setState(() => _currentMessageIndex = newIndex);
      }
    });

    // Don't auto-start — wait until this step becomes visible
  }

  /// Called by the parent when this step becomes the active page.
  void startAnimation() {
    if (_started) return;
    _started = true;
    _progressController.forward().then((_) async {
      if (!mounted) return;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing logo
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 48),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Personalizing your plan',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _messages[_currentMessageIndex],
                    key: ValueKey(_currentMessageIndex),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) => Text(
                    '${(_progressAnimation.value * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Saving indicator
                Consumer<OnboardingProvider>(
                  builder: (context, provider, _) {
                    if (provider.isSaving) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Saving your profile...',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
