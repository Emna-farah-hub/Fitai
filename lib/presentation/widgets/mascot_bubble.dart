import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class MascotBubble extends StatefulWidget {
  final String explanation;
  final VoidCallback? onMore;

  const MascotBubble({super.key, required this.explanation, this.onMore});

  @override
  State<MascotBubble> createState() => _MascotBubbleState();
}

class _MascotBubbleState extends State<MascotBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _eyeScale;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _eyeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_blinkController);
    _scheduleBlink();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 3000 + math.Random().nextInt(1000));
    _blinkTimer = Timer(delay, () async {
      if (!mounted) return;
      await _blinkController.forward(from: 0);
      if (mounted) _scheduleBlink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _eyeScale,
              builder: (context, _) {
                return CustomPaint(
                  painter: _MascotFacePainter(eyeScale: _eyeScale.value),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this question?',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.explanation,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: widget.onMore,
                  child: Text(
                    'More',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotFacePainter extends CustomPainter {
  final double eyeScale;

  const _MascotFacePainter({required this.eyeScale});

  @override
  void paint(Canvas canvas, Size size) {
    final faceCenter = Offset(size.width / 2, size.height / 2 + 3);
    final faceRadius = size.width * 0.34;

    final facePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(faceCenter, faceRadius, facePaint);

    final leafPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.fill;
    _drawLeaf(
      canvas,
      center: Offset(size.width * 0.43, size.height * 0.18),
      angle: -0.75,
      paint: leafPaint,
    );
    _drawLeaf(
      canvas,
      center: Offset(size.width * 0.58, size.height * 0.17),
      angle: 0.75,
      paint: leafPaint,
    );

    final eyePaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;
    _drawEye(canvas, Offset(size.width * 0.39, size.height * 0.42), eyePaint);
    _drawEye(canvas, Offset(size.width * 0.61, size.height * 0.42), eyePaint);

    final cheekPaint = Paint()
      ..color = AppColors.amber.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.34, size.height * 0.55),
      4,
      cheekPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.66, size.height * 0.55),
      4,
      cheekPaint,
    );

    final smilePaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.6),
        width: 18,
        height: 12,
      ),
      0.15,
      math.pi - 0.3,
      false,
      smilePaint,
    );
  }

  void _drawEye(Canvas canvas, Offset center, Paint paint) {
    final height = (5 * eyeScale).clamp(0.4, 5.0);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 4, height: height),
      paint,
    );
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset center,
    required double angle,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 18, height: 9),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MascotFacePainter oldDelegate) {
    return oldDelegate.eyeScale != eyeScale;
  }
}
