import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Step 1: Ask for the user's name.
class StepName extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepName({super.key, required this.onNext, required this.onBack});

  @override
  State<StepName> createState() => _StepNameState();
}

class _StepNameState extends State<StepName> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _controller.text = provider.name;
    _controller.addListener(() {
      context.read<OnboardingProvider>().setName(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) => OnboardingScaffold(
        currentStep: provider.currentStep,
        totalSteps: provider.totalSteps,
        question: AppStrings.onboardingTitles[1],
        questionSubtitle: AppStrings.onboardingSubtitles[1],
        illustrationPath: AppAssets.nameIllustration,
        fallbackIcon: Icons.person_rounded,
        canContinue: provider.name.trim().isNotEmpty,
        onBack: widget.onBack,
        onContinue: widget.onNext,
        content: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: provider.name.trim().isNotEmpty
              ? (_) => widget.onNext()
              : null,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'e.g. Ahmed',
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
