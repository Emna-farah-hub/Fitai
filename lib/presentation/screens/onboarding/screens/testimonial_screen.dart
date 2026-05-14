import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../widgets/press_scale.dart';

const Color _testimonialBg = AppColors.backgroundAlt;
const Color _testimonialAccent = AppColors.amber;
const Color _testimonialDark = AppColors.textPrimary;

class TestimonialScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const TestimonialScreen({super.key, required this.onContinue});

  @override
  State<TestimonialScreen> createState() => _TestimonialScreenState();
}

class _TestimonialScreenState extends State<TestimonialScreen> {
  static const String _quote =
      'I never thought I could stick to a plan. FitAI made it feel natural.';

  int _visibleChars = 0;
  bool _quoteDone = false;

  @override
  void initState() {
    super.initState();
    _typeQuote();
  }

  Future<void> _typeQuote() async {
    for (int i = 1; i <= _quote.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 18));
      if (!mounted) return;
      setState(() => _visibleChars = i);
    }
    if (!mounted) return;
    setState(() => _quoteDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _testimonialBg,
      body: SafeArea(
        child: Stack(
          children: [
            const _StoryBackdrop(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _StoryIllustration()
                      .animate()
                      .fadeIn(duration: 340.ms)
                      .slideY(
                        begin: 0.12,
                        end: 0,
                        duration: 340.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _testimonialAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Member story',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amberDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '"${_quote.substring(0, _visibleChars)}"',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: _testimonialDark,
                            height: 1.42,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedOpacity(
                          opacity: _quoteDone ? 1 : 0,
                          duration: const Duration(milliseconds: 260),
                          child: Column(
                            children: [
                              Text(
                                'Sarah, reached her goal in 3 months',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _testimonialAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (int i = 0; i < 5; i++) ...[
                                    Icon(
                                          Icons.star_rounded,
                                          size: 20,
                                          color: _testimonialAccent,
                                        )
                                        .animate(target: _quoteDone ? 1 : 0)
                                        .scale(
                                          begin: const Offset(0, 0),
                                          end: const Offset(1.14, 1.14),
                                          duration: 180.ms,
                                          delay: Duration(milliseconds: i * 90),
                                          curve: Curves.easeOutBack,
                                        )
                                        .then()
                                        .scale(
                                          begin: const Offset(1.14, 1.14),
                                          end: const Offset(1, 1),
                                          duration: 120.ms,
                                          curve: Curves.easeOut,
                                        ),
                                    if (i < 4) const SizedBox(width: 10),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  PressScale(
                        onPressed: widget.onContinue,
                        pressedScale: 0.97,
                        invokeDelay: const Duration(milliseconds: 50),
                        child: SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _testimonialAccent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _testimonialAccent.withValues(
                                    alpha: 0.24,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Continue',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 420.ms, delay: 900.ms)
                      .slideY(
                        begin: 0.34,
                        end: 0,
                        duration: 500.ms,
                        delay: 900.ms,
                        curve: Curves.elasticOut,
                      ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryBackdrop extends StatelessWidget {
  const _StoryBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x12F2B441),
                    Color(0x04F2B441),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -34,
            bottom: 150,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x0E84A98C),
                    Color(0x0384A98C),
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

class _StoryIllustration extends StatelessWidget {
  const _StoryIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 26,
            child: Container(
              width: 164,
              height: 94,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 54,
            child: _Bubble(text: '+ confidence'),
          ),
          Positioned(right: 28, bottom: 84, child: _Bubble(text: 'habits')),
          Positioned(
            top: 18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _testimonialAccent,
                size: 42,
              ),
            ),
          ),
          Positioned(
            bottom: 36,
            child: Container(
              width: 122,
              height: 12,
              decoration: BoxDecoration(
                color: _testimonialDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;

  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _testimonialDark,
        ),
      ),
    );
  }
}
