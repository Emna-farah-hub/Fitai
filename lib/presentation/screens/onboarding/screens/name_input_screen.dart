import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/fitai_brand_mark.dart';
import '../../../widgets/onboarding_question_scaffold.dart';

class NameInputScreen extends StatefulWidget {
  final Color paleColor;
  final Color accentColor;
  final int currentSection;
  final double progressInSection;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const NameInputScreen({
    super.key,
    required this.paleColor,
    required this.accentColor,
    required this.currentSection,
    required this.progressInSection,
    required this.onNext,
    this.onBack,
  });

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _showReaction = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _controller = TextEditingController(text: provider.name);
    _focusNode = FocusNode()
      ..addListener(() {
        if (mounted) setState(() => _focused = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_navigating) return;
    final name = _controller.text.trim();
    if (name.length < 2) return;

    context.read<OnboardingProvider>().setName(name);
    _focusNode.unfocus();
    setState(() {
      _showReaction = true;
      _navigating = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final name = provider.name.trim();
        final canContinue = name.length >= 2 && !_navigating;

        return OnboardingQuestionScaffold(
          backgroundColor: widget.paleColor,
          currentSection: widget.currentSection,
          progressInSection: widget.progressInSection,
          accentColor: widget.accentColor,
          onBack: _navigating ? null : widget.onBack,
          onNext: _handleNext,
          isNextEnabled: canContinue,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 220,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        'What should we call you?',
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
                        "We'll use your name to make your plan feel personal from the start.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.35,
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
                  const SizedBox(height: 40),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _NameMascot(
                                accentColor: widget.accentColor,
                                isTyping:
                                    !_showReaction &&
                                    (name.isNotEmpty || _focused),
                                isCelebrating: _showReaction,
                              )
                              .animate()
                              .fadeIn(duration: 300.ms, delay: 180.ms)
                              .slideY(
                                begin: 18 / 120,
                                end: 0,
                                duration: 300.ms,
                                delay: 180.ms,
                                curve: Curves.easeOutCubic,
                              ),
                          const SizedBox(height: 28),
                          AnimatedOpacity(
                            opacity: _showReaction ? 0.6 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: AnimatedSlide(
                              offset: _showReaction
                                  ? const Offset(0, 0.08)
                                  : Offset.zero,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeInOut,
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _focused
                                        ? widget.accentColor
                                        : AppColors.border,
                                    width: 1.8,
                                  ),
                                  boxShadow: _focused
                                      ? [
                                          BoxShadow(
                                            color: widget.accentColor
                                                .withValues(alpha: 0.10),
                                            blurRadius: 0,
                                            spreadRadius: 3,
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  enabled: !_navigating,
                                  textAlign: TextAlign.center,
                                  textInputAction: TextInputAction.done,
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: provider.setName,
                                  onSubmitted: (_) => _handleNext(),
                                  style: GoogleFonts.nunito(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Your name',
                                    hintStyle: GoogleFonts.nunito(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _showReaction
                                ? Text(
                                        'Nice to meet you, $name!',
                                        key: const ValueKey('reaction'),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.nunito(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: widget.accentColor,
                                        ),
                                      )
                                      .animate()
                                      .scale(
                                        begin: const Offset(0.86, 0.86),
                                        end: const Offset(1, 1),
                                        duration: 500.ms,
                                        curve: Curves.elasticOut,
                                      )
                                      .fadeIn(duration: 140.ms)
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NameMascot extends StatelessWidget {
  final Color accentColor;
  final bool isTyping;
  final bool isCelebrating;

  const _NameMascot({
    required this.accentColor,
    required this.isTyping,
    required this.isCelebrating,
  });

  @override
  Widget build(BuildContext context) {
    Widget mascot = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: isCelebrating ? 124 : 112,
      height: isCelebrating ? 124 : 112,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surfaceSoft],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primarySoft, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: const Center(child: FitAiBrandMark(size: 66, playEntrance: false)),
    );

    if (isTyping) {
      mascot = mascot
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(begin: -3, end: 3, duration: 1100.ms, curve: Curves.easeInOut)
          .scale(
            begin: const Offset(0.98, 0.98),
            end: const Offset(1.02, 1.02),
            duration: 1100.ms,
            curve: Curves.easeInOut,
          );
    }

    if (isCelebrating) {
      mascot = mascot.animate().scale(
        begin: const Offset(0.92, 0.92),
        end: const Offset(1.04, 1.04),
        duration: 420.ms,
        curve: Curves.easeOutBack,
      );
    }

    return SizedBox(
      width: 152,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          mascot,
          if (isCelebrating)
            Positioned(
              right: 6,
              top: 8,
              child:
                  Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.waving_hand_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .rotate(
                        begin: -0.10,
                        end: 0.12,
                        duration: 520.ms,
                        curve: Curves.easeInOut,
                      ),
            ),
        ],
      ),
    );
  }
}
