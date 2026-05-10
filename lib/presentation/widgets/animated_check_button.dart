import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class AnimatedCheckButton extends StatefulWidget {
  final FutureOr<void> Function() onConfirm;
  final bool isConfirmed;
  final String label;
  final String confirmedLabel;
  final double height;
  final BorderRadius borderRadius;

  const AnimatedCheckButton({
    super.key,
    required this.onConfirm,
    required this.isConfirmed,
    this.label = 'I ate this',
    this.confirmedLabel = '✓ EATEN',
    this.height = 44,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<AnimatedCheckButton> createState() => _AnimatedCheckButtonState();
}

class _AnimatedCheckButtonState extends State<AnimatedCheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isSubmitting = false;
  bool _showFinalBadge = false;

  @override
  void initState() {
    super.initState();
    _showFinalBadge = widget.isConfirmed;
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 850),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _showFinalBadge = true);
          }
        });
  }

  @override
  void didUpdateWidget(covariant AnimatedCheckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isConfirmed && widget.isConfirmed) {
      _playConfirmation();
    } else if (oldWidget.isConfirmed && !widget.isConfirmed) {
      _controller.reset();
      _showFinalBadge = false;
      _isSubmitting = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isSubmitting || widget.isConfirmed) return;
    setState(() => _isSubmitting = true);
    _playConfirmation();
    await Future<void>.delayed(_controller.duration!);
    await widget.onConfirm();
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _playConfirmation() {
    if (!mounted) return;
    setState(() {
      _showFinalBadge = false;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_showFinalBadge) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _EatenBadge(label: widget.confirmedLabel),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        final backgroundColor = Color.lerp(
          AppColors.primary,
          AppColors.primaryLight,
          Curves.easeOut.transform((value / 0.12).clamp(0.0, 1.0)),
        )!;
        final textOpacity =
            1 -
            Curves.easeOut.transform(((value - 0.12) / 0.18).clamp(0.0, 1.0));
        final checkProgress = Curves.easeOut.transform(
          ((value - 0.12) / 0.18).clamp(0.0, 1.0),
        );
        final scale = TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 250),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 1.08,
            ).chain(CurveTween(curve: Curves.elasticOut)),
            weight: 100,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.08,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 100,
          ),
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 400),
        ]).transform(value);
        final particleProgress = Curves.easeOut.transform(
          ((value - 0.53) / 0.47).clamp(0.0, 1.0),
        );

        return Transform.scale(
          scale: scale,
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: widget.borderRadius,
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleTap,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (checkProgress > 0)
                  CustomPaint(
                    size: const Size(28, 28),
                    painter: _CheckmarkPainter(progress: checkProgress),
                  ),
                if (particleProgress > 0)
                  for (var i = 0; i < 6; i++)
                    _Particle(index: i, progress: particleProgress),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EatenBadge extends StatelessWidget {
  final String label;

  const _EatenBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Particle extends StatelessWidget {
  final int index;
  final double progress;

  const _Particle({required this.index, required this.progress});

  @override
  Widget build(BuildContext context) {
    final angle = index * math.pi / 3;
    final distance = 24 * progress;
    return Transform.translate(
      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
      child: Opacity(
        opacity: 1 - progress,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;

  const _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final circleProgress = (progress / 0.55).clamp(0.0, 1.0);
    final checkProgress = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      paint,
    );

    if (checkProgress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * checkProgress),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
