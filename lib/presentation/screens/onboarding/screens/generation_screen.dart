import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/fitai_plate_logo.dart';

class GenerationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const GenerationScreen({super.key, required this.onComplete});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _phases = [
    'Understanding your taste profile',
    'Calculating your daily calorie target',
    'Choosing meals that fit your preferences',
    'Building your 7-day nutrition plan',
    'Finalizing your dashboard setup',
  ];

  late final AnimationController _progressController;
  Timer? _phaseTimer;
  int _phaseIndex = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();
    _phaseTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _phaseIndex = (_phaseIndex + 1).clamp(0, _phases.length - 1);
      });
      if (_phaseIndex == _phases.length - 1) timer.cancel();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final minDuration = Future<void>.delayed(const Duration(seconds: 10));
    final save = _saveProfile();
    final results = await Future.wait([minDuration, save]);
    if (!mounted) return;

    final saved = results[1] as bool;
    if (saved) {
      widget.onComplete();
    } else {
      setState(() => _failed = true);
    }
  }

  Future<bool> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final onboarding = context.read<OnboardingProvider>();
    final user = auth.currentUser;
    if (user == null) return false;

    onboarding.calculatePlan();
    final saved = await onboarding.saveProfile(user.uid);
    if (!mounted || !saved) return saved;
    await context.read<UserProvider>().loadProfile(user.uid);
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: Stack(
        children: [
          const _GenerationBackdrop(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.13),
                            Colors.white.withValues(alpha: 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: FitAiPlateLogo(
                          size: 116,
                          animateDots: true,
                          dotDuration: Duration(milliseconds: 900),
                          dotStagger: Duration(milliseconds: 1800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      _failed
                          ? 'We couldn’t save your plan just yet.'
                          : 'Creating your 7-day plan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _failed
                            ? 'Please try again. Your answers are still here.'
                            : _phases[_phaseIndex],
                        key: ValueKey('${_failed}_$_phaseIndex'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        width: double.infinity,
                        color: Colors.white.withValues(alpha: 0.14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                widthFactor: _progressController.value,
                                child: child,
                              );
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.amber,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _phases.length; i++) ...[
                            _PhaseRow(
                              label: _phases[i],
                              active: i == _phaseIndex && !_failed,
                              complete: i < _phaseIndex && !_failed,
                            ),
                            if (i < _phases.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _failed = false;
                            _phaseIndex = 0;
                          });
                          _progressController
                            ..reset()
                            ..forward();
                          _generate();
                        },
                        child: Text(
                          'Try again',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationBackdrop extends StatelessWidget {
  const _GenerationBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, AppColors.tealDark],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1816A34A),
                    Color(0x0516A34A),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 80,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x0FF2B441),
                    Color(0x03F2B441),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String label;
  final bool active;
  final bool complete;

  const _PhaseRow({
    required this.label,
    required this.active,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? AppColors.primaryLight
        : active
        ? AppColors.amber
        : Colors.white.withValues(alpha: 0.34);

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: active || complete ? 0.18 : 0.10),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(
            complete ? Icons.check_rounded : Icons.circle,
            size: complete ? 14 : 8,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white.withValues(
                alpha: active || complete ? 0.90 : 0.58,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
