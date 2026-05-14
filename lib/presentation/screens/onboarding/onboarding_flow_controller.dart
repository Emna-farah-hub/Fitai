import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../agent/agent_scheduler.dart';
import '../../../agent/core/agent_event.dart';
import '../../../agent/orchestrator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../screens/swipe_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/onboarding_bottom_nav.dart';
import '../../widgets/onboarding_progress_bar.dart';
import '../../widgets/section_intro_screen.dart';
import 'screens/activity_level_screen.dart';
import 'screens/ai_coach_screen.dart';
import 'screens/age_picker_screen.dart';
import 'screens/allergies_screen.dart';
import 'screens/avoid_foods_screen.dart';
import 'screens/celebration_screen.dart';
import 'screens/commitment_screen.dart';
import 'screens/cooking_screen.dart';
import 'screens/cuisine_screen.dart';
import 'screens/diet_type_screen.dart';
import 'screens/experience_screen.dart';
import 'screens/gender_screen.dart';
import 'screens/generation_screen.dart';
import 'screens/goal_selection_screen.dart';
import 'screens/height_screen.dart';
import 'screens/meal_frequency_screen.dart';
import 'screens/motivation_screen.dart';
import 'screens/motivational_bridge_screen.dart';
import 'screens/name_input_screen.dart';
import 'screens/pace_screen.dart';
import 'screens/social_proof_screen.dart';
import 'screens/struggles_screen.dart';
import 'screens/target_weight_screen.dart';
import 'screens/testimonial_screen.dart';
import 'screens/weight_screen.dart';

/// Drives the onboarding experience.
///
/// Layout of indices:
///   0           SocialProofScreen
///   1           Section 1 intro — Your Goals
///   2           GoalSelectionScreen
///   3           MotivationScreen
///   4           MotivationalBridgeScreen
///   5           Section 2 intro
///   6           NameInputScreen
///   7           GenderScreen
///   8           AgePickerScreen
///   9           HeightScreen
///   10          WeightScreen
///   11          TargetWeightScreen
///   12          Section 3 intro
///   13          ActivityLevelScreen
///   14          ExperienceScreen
///   15          StrugglesScreen
///   16          PaceScreen
///   17          MealFrequencyScreen
///   18          TestimonialScreen
///   19          Section 4 intro
///   20          DietTypeScreen
///   21          AllergiesScreen
///   22          CuisineScreen
///   23          CookingScreen
///   24          AvoidFoodsScreen
///   25          Section 5 intro
///   26          AiCoachScreen
///   27          CommitmentScreen
///   28          Section 6 intro
///   29          SwipeScreen
///   30          GenerationScreen
///
/// All screens are placeholder stubs for now — they show the screen name
/// Sections 1 and 2 have real screens; later sections are still placeholder
/// stubs.
/// Section-intro slots use the shared [SectionIntroScreen] widget.
class OnboardingFlowController extends StatefulWidget {
  const OnboardingFlowController({super.key});

  @override
  State<OnboardingFlowController> createState() =>
      _OnboardingFlowControllerState();
}

class _OnboardingFlowControllerState extends State<OnboardingFlowController> {
  static const int _totalScreens = 32;

  static const List<_SectionDef> _sections = [
    _SectionDef(
      number: '01',
      label: 'SECTION 01',
      title: 'Your Goals',
      subtitle: "Let's understand what you want to achieve.",
      darkColor: AppColors.primaryDark,
      paleColor: AppColors.primarySurface,
      accentColor: AppColors.primaryLight,
    ),
    _SectionDef(
      number: '02',
      label: 'SECTION 02',
      title: 'About You',
      subtitle: 'A few details so we can personalize your plan.',
      darkColor: AppColors.tealDark,
      paleColor: AppColors.infoSurface,
      accentColor: AppColors.tealLight,
    ),
    _SectionDef(
      number: '03',
      label: 'SECTION 03',
      title: 'Your Rhythm',
      subtitle: 'A plan that fits your routine is easier to keep.',
      darkColor: AppColors.amberDark,
      paleColor: AppColors.amberSoft,
      accentColor: AppColors.amber,
    ),
    _SectionDef(
      number: '04',
      label: 'SECTION 04',
      title: 'What You Love',
      subtitle: 'Tell us what fits your taste and table.',
      darkColor: AppColors.sageDark,
      paleColor: AppColors.sageSoft,
      accentColor: AppColors.sage,
    ),
    _SectionDef(
      number: '05',
      label: 'SECTION 05',
      title: 'Your Plan',
      subtitle: 'Your personalized nutrition plan is almost ready.',
      darkColor: AppColors.primaryDark,
      paleColor: AppColors.primarySurface,
      accentColor: AppColors.primary,
    ),
    _SectionDef(
      number: '06',
      label: 'SECTION 06',
      title: 'Your Taste',
      subtitle:
          'Swipe through meals so we can learn what you would actually enjoy eating.',
      darkColor: AppColors.tealDark,
      paleColor: AppColors.backgroundAlt,
      accentColor: AppColors.primaryLight,
    ),
  ];

  // Inclusive [start, end] index ranges for each section (intro + questions).
  static const List<List<int>> _sectionRanges = [
    [1, 4],
    [5, 11],
    [12, 18],
    [19, 24],
    [25, 27],
    [28, 30],
  ];

  static const Set<int> _introIndices = {1, 5, 12, 19, 25, 28};
  static const Set<int> _fadeTransitionIndices = {4, 18, 26, 28, 29, 30, 31};

  int currentIndex = 0;
  int _previousIndex = 0;

  void goNext() {
    if (currentIndex < _totalScreens - 1) {
      setState(() {
        _previousIndex = currentIndex;
        currentIndex++;
      });
    } else {
      context.go('/dashboard');
    }
  }

  void goBack() {
    if (currentIndex > 0) {
      setState(() {
        _previousIndex = currentIndex;
        currentIndex--;
      });
    }
  }

  Future<void> _finishOnboardingToDashboard() async {
    final auth = context.read<AuthProvider>();
    final onboarding = context.read<OnboardingProvider>();
    final userProvider = context.read<UserProvider>();
    final user = auth.currentUser;

    if (user == null) {
      if (mounted) context.go('/dashboard');
      return;
    }

    await onboarding.completeOnboarding(user.uid);
    if (!mounted) return;

    await userProvider.loadProfile(user.uid);
    if (!mounted) return;

    // Kick off the agent for the first time: this generates the initial
    // 7-day plan, then the scheduler begins firing morning/midday/evening
    // briefings on the right time-of-day boundaries.
    unawaited(
      AgentOrchestrator().handle(
        AgentEvent.now(
          type: AgentEventType.onboardingComplete,
          uid: user.uid,
        ),
      ),
    );
    AgentScheduler().start(user.uid);

    context.go('/dashboard');
  }

  Future<void> _confirmLeaveOnboarding() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Leave onboarding?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Are you sure you want to leave? Your progress will be saved.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true && mounted) {
      context.go('/dashboard');
    }
  }

  int _sectionIndex(int i) {
    for (int s = 0; s < _sectionRanges.length; s++) {
      final range = _sectionRanges[s];
      if (i >= range[0] && i <= range[1]) return s;
    }
    return 0; // welcome falls back to section 1's palette
  }

  /// 1-based section number for the progress bar.
  int _currentSection(int i) => _sectionIndex(i) + 1;

  Color _backgroundForIndex(int i) => _sections[_sectionIndex(i)].paleColor;

  bool _usesFadeTransition(int i) => _fadeTransitionIndices.contains(i);

  /// Fraction (0.0–1.0) of how far we are through the current section.
  double _progressInSection(int i) {
    if (i == 0) return 0;
    final section = _sectionIndex(i);
    final range = _sectionRanges[section];
    final start = range[0];
    final end = range[1];
    final questionCount = end - start; // screens after the intro
    if (questionCount <= 0 || i <= start) return 0;
    if (questionCount == 1) return 1;
    final positionInQuestions = i - start - 1; // 0 at first question
    return (positionInQuestions / (questionCount - 1)).clamp(0.0, 1.0);
  }

  String _screenName(int i) {
    if (i == 0) return 'Welcome';
    if (_introIndices.contains(i)) {
      return 'Section ${_currentSection(i)} Intro';
    }
    final section = _sectionIndex(i);
    final range = _sectionRanges[section];
    final qNumber = i - range[0]; // 1-based question number
    return 'Section ${section + 1} · Question $qNumber';
  }

  Widget _buildScreen(int i) {
    if (i == 0) {
      return SocialProofScreen(onNext: goNext);
    }

    final sectionDef = _sections[_sectionIndex(i)];

    if (_introIndices.contains(i)) {
      return SectionIntroScreen(
        sectionNumber: sectionDef.number,
        sectionLabel: sectionDef.label,
        title: sectionDef.title,
        subtitle: sectionDef.subtitle,
        backgroundColor: sectionDef.darkColor,
        accentColor: sectionDef.accentColor,
        onContinue: goNext,
      );
    }

    if (i == 2) {
      return GoalSelectionScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 3) {
      return MotivationScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 4) {
      return MotivationalBridgeScreen(onContinue: goNext);
    }

    if (i == 6) {
      return NameInputScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 7) {
      return GenderScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 8) {
      return AgePickerScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 9) {
      return HeightScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 10) {
      return WeightScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 11) {
      return TargetWeightScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 13) {
      return ActivityLevelScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 14) {
      return ExperienceScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 15) {
      return StrugglesScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 16) {
      return PaceScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 17) {
      return MealFrequencyScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 18) {
      return TestimonialScreen(onContinue: goNext);
    }

    if (i == 20) {
      return DietTypeScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 21) {
      return AllergiesScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 22) {
      return CuisineScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 23) {
      return CookingScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 24) {
      return AvoidFoodsScreen(
        paleColor: sectionDef.paleColor,
        accentColor: sectionDef.accentColor,
        currentSection: _currentSection(i),
        progressInSection: _progressInSection(i),
        onBack: goBack,
        onNext: goNext,
      );
    }

    if (i == 26) {
      return AiCoachScreen(onNext: goNext);
    }

    if (i == 27) {
      return CommitmentScreen(onNext: goNext);
    }

    if (i == 28) {
      return SectionIntroScreen(
        sectionNumber: sectionDef.number,
        sectionLabel: sectionDef.label,
        title: sectionDef.title,
        subtitle: sectionDef.subtitle,
        backgroundColor: sectionDef.darkColor,
        accentColor: sectionDef.accentColor,
        onContinue: goNext,
      );
    }

    if (i == 29) {
      return SwipeScreen(isOnboarding: true, onComplete: goNext);
    }

    if (i == 30) {
      // After the plan is generated + profile is saved, advance to the
      // celebration step. The actual dashboard handoff happens from there so
      // the agent kick-off only fires once, after the user explicitly enters.
      return GenerationScreen(onComplete: goNext);
    }

    if (i == 31) {
      return CelebrationScreen(onContinue: _finishOnboardingToDashboard);
    }

    return Scaffold(
      backgroundColor: sectionDef.paleColor,
      body: SafeArea(
        child: Column(
          children: [
            if (i != 0) ...[
              const SizedBox(height: 12),
              OnboardingProgressBar(
                currentSection: _currentSection(i),
                progressInSection: _progressInSection(i),
                accentColor: sectionDef.accentColor,
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _screenName(i),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            OnboardingBottomNav(
              onBack: currentIndex == 0 ? null : goBack,
              onNext: goNext,
              nextLabel: currentIndex == _totalScreens - 1 ? 'Finish' : 'Next',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movingForward = currentIndex >= _previousIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeaveOnboarding();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: _backgroundForIndex(currentIndex),
        child: AnimatedSwitcher(
          duration: _usesFadeTransition(currentIndex)
              ? const Duration(milliseconds: 400)
              : const Duration(milliseconds: 280),
          reverseDuration: _usesFadeTransition(_previousIndex)
              ? const Duration(milliseconds: 400)
              : const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            final key = child.key;
            final childIndex = key is ValueKey<int> ? key.value : currentIndex;
            final incoming = childIndex == currentIndex;
            final useFade =
                _usesFadeTransition(childIndex) ||
                _usesFadeTransition(currentIndex);

            if (useFade) {
              return FadeTransition(opacity: animation, child: child);
            }

            final curve = incoming
                ? Curves.easeOutCubic
                : movingForward
                ? Curves.easeOutCubic
                : Curves.easeInCubic;
            final curved = CurvedAnimation(parent: animation, curve: curve);

            final tween = incoming
                ? Tween<Offset>(
                    begin: movingForward
                        ? const Offset(1, 0)
                        : const Offset(-0.12, 0),
                    end: Offset.zero,
                  )
                : Tween<Offset>(
                    begin: movingForward
                        ? const Offset(-0.12, 0)
                        : const Offset(1, 0),
                    end: Offset.zero,
                  );

            return SlideTransition(
              position: tween.animate(curved),
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: _buildScreen(currentIndex),
          ),
        ),
      ),
    );
  }
}

class _SectionDef {
  final String number;
  final String label;
  final String title;
  final String subtitle;
  final Color darkColor;
  final Color paleColor;
  final Color accentColor;

  const _SectionDef({
    required this.number,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.darkColor,
    required this.paleColor,
    required this.accentColor,
  });
}
