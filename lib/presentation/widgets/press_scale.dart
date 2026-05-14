import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double pressedScale;
  final Duration invokeDelay;
  final bool haptic;

  const PressScale({
    super.key,
    required this.child,
    required this.onPressed,
    this.pressedScale = 0.98,
    this.invokeDelay = Duration.zero,
    this.haptic = false,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _updateScale();
  }

  @override
  void didUpdateWidget(covariant PressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressedScale != widget.pressedScale) {
      _updateScale();
    }
  }

  void _updateScale() {
    _scale = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final callback = widget.onPressed;
    if (callback == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    await _controller.forward();
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    if (widget.invokeDelay > Duration.zero) {
      await Future<void>.delayed(widget.invokeDelay);
      if (!mounted) return;
    }
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? _handleTap : null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
