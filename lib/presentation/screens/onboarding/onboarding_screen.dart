import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import 'steps/step_welcome.dart';
import 'steps/step_name.dart';
import 'steps/step_birthday.dart';
import 'steps/step_height.dart';
import 'steps/step_weight.dart';
import 'steps/step_sex.dart';
import 'steps/step_activity.dart';
import 'steps/step_fitness.dart';
import 'steps/step_conditions.dart';
import 'steps/step_goals.dart';
import 'steps/step_dietary.dart';
import 'steps/step_personalizing.dart';

/// Main onboarding screen — orchestrates all 12 steps using a PageView.
/// Each step widget is responsible for its own UI; this screen handles navigation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _personalizingKey = GlobalKey<StepPersonalizingState>();

  @override
  void initState() {
    super.initState();
    // Reset onboarding state in case of a previous incomplete session
    context.read<OnboardingProvider>().reset();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() {
    final provider = context.read<OnboardingProvider>();
    provider.nextStep();
    final step = provider.currentStep;
    _goToPage(step);

    // If we just arrived at the personalizing step, start its animation
    if (step == 11) {
      // Wait for the page animation to complete before starting
      Future.delayed(const Duration(milliseconds: 450), () {
        _personalizingKey.currentState?.startAnimation();
      });
    }
  }

  void _prevStep() {
    final provider = context.read<OnboardingProvider>();
    provider.previousStep();
    _goToPage(provider.currentStep);
  }

  Future<void> _completeOnboarding() async {
    final authProvider = context.read<AuthProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();

    final uid = authProvider.currentUser?.uid;
    if (uid == null) return;

    final success = await onboardingProvider.saveProfile(uid);
    if (!mounted) return;

    if (success) {
      context.go('/agent-onboarding');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onboardingProvider.errorMessage ?? 'Failed to save profile',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      // Disable swipe — navigation is handled by buttons only
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Step 0: Welcome
        StepWelcome(onNext: _nextStep),
        // Step 1: Name
        StepName(onNext: _nextStep, onBack: _prevStep),
        // Step 2: Birthday
        StepBirthday(onNext: _nextStep, onBack: _prevStep),
        // Step 3: Height
        StepHeight(onNext: _nextStep, onBack: _prevStep),
        // Step 4: Weight
        StepWeight(onNext: _nextStep, onBack: _prevStep),
        // Step 5: Sex
        StepSex(onNext: _nextStep, onBack: _prevStep),
        // Step 6: Activity level
        StepActivity(onNext: _nextStep, onBack: _prevStep),
        // Step 7: Fitness level
        StepFitness(onNext: _nextStep, onBack: _prevStep),
        // Step 8: Health conditions
        StepConditions(onNext: _nextStep, onBack: _prevStep),
        // Step 9: Goals
        StepGoals(onNext: _nextStep, onBack: _prevStep),
        // Step 10: Dietary preference
        StepDietary(onNext: _nextStep, onBack: _prevStep),
        // Step 11: Personalizing (saves profile → navigates to agent onboarding)
        StepPersonalizing(key: _personalizingKey, onComplete: _completeOnboarding),
      ],
    );
  }
}
