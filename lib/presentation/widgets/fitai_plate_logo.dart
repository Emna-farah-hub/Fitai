import 'package:flutter/material.dart';

import 'fitai_brand_mark.dart';

class FitAiPlateLogo extends StatefulWidget {
  final double size;
  final bool float;
  final bool animateDots;
  final Duration dotDuration;
  final Duration dotStagger;

  const FitAiPlateLogo({
    super.key,
    this.size = 88,
    this.float = false,
    this.animateDots = false,
    this.dotDuration = const Duration(milliseconds: 800),
    this.dotStagger = const Duration(milliseconds: 200),
  });

  @override
  State<FitAiPlateLogo> createState() => _FitAiPlateLogoState();
}

class _FitAiPlateLogoState extends State<FitAiPlateLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.float) _floatController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant FitAiPlateLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.float && !_floatController.isAnimating) {
      _floatController.repeat(reverse: true);
    } else if (!widget.float && _floatController.isAnimating) {
      _floatController.stop();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = _LogoBody(
      size: widget.size,
      animateDots: widget.animateDots,
      dotDuration: widget.dotDuration,
      dotStagger: widget.dotStagger,
    );

    if (!widget.float) return logo;

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_floatController.value);
        return Transform.translate(offset: Offset(0, -7 * t), child: child);
      },
      child: logo,
    );
  }
}

class _LogoBody extends StatelessWidget {
  final double size;
  final bool animateDots;
  final Duration dotDuration;
  final Duration dotStagger;

  const _LogoBody({
    required this.size,
    required this.animateDots,
    required this.dotDuration,
    required this.dotStagger,
  });

  @override
  Widget build(BuildContext context) {
    return FitAiBrandMark(size: size, playEntrance: animateDots);
  }
}
