import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class FitAiBodyFigure extends StatelessWidget {
  final Color color;
  final double heightFactor;

  const FitAiBodyFigure({
    super.key,
    required this.color,
    this.heightFactor = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: heightFactor.clamp(0.92, 1.06),
      alignment: Alignment.center,
      child: SizedBox(
        width: 140,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 22,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              child: Container(
                width: 116,
                height: 188,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(58),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: 84,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowRulerMarker {
  final double value;
  final String label;
  final Color color;

  const WindowRulerMarker({
    required this.value,
    required this.label,
    required this.color,
  });
}

class VerticalHeightRuler extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final String Function(int tick)? labelFormatter;
  final double indicatorFraction;
  final double width;
  final double height;
  final double pixelsPerUnit;

  const VerticalHeightRuler({
    super.key,
    required this.value,
    this.min = 140,
    this.max = 210,
    required this.accentColor,
    required this.onChanged,
    this.labelFormatter,
    this.indicatorFraction = 0.5,
    this.width = 196,
    this.height = 332,
    this.pixelsPerUnit = 10,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => _handleDrag(details.delta.dy),
      onTapDown: (details) => _handleTap(context, details.localPosition),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _VerticalWindowRulerPainter(
            value: value,
            min: min,
            max: max,
            accentColor: accentColor,
            labelFormatter: labelFormatter,
            indicatorFraction: indicatorFraction,
            pixelsPerUnit: pixelsPerUnit,
          ),
        ),
      ),
    );
  }

  void _handleDrag(double deltaDy) {
    final next = (value - (deltaDy / pixelsPerUnit)).clamp(min, max);
    onChanged(next.toDouble());
  }

  void _handleTap(BuildContext context, Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final indicatorY = box.size.height * indicatorFraction;
    final deltaUnits = (indicatorY - localPosition.dy) / pixelsPerUnit;
    final next = (value + deltaUnits).clamp(min, max);
    onChanged(next.toDouble());
  }
}

class HorizontalWeightRuler extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final List<WindowRulerMarker> markers;
  final double height;
  final double pixelsPerUnit;

  const HorizontalWeightRuler({
    super.key,
    required this.value,
    this.min = 40,
    this.max = 180,
    required this.accentColor,
    required this.onChanged,
    this.markers = const [],
    this.height = 168,
    this.pixelsPerUnit = 11,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => _handleDrag(details.delta.dx),
      onTapDown: (details) => _handleTap(context, details.localPosition),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _HorizontalWindowRulerPainter(
            value: value,
            min: min,
            max: max,
            accentColor: accentColor,
            pixelsPerUnit: pixelsPerUnit,
            markers: markers,
          ),
        ),
      ),
    );
  }

  void _handleDrag(double deltaDx) {
    final next = (value + (deltaDx / pixelsPerUnit)).clamp(min, max);
    onChanged(next.toDouble());
  }

  void _handleTap(BuildContext context, Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final centerX = box.size.width / 2;
    final deltaUnits = (localPosition.dx - centerX) / pixelsPerUnit;
    final next = (value + deltaUnits).clamp(min, max);
    onChanged(next.toDouble());
  }
}

class _VerticalWindowRulerPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final Color accentColor;
  final String Function(int tick)? labelFormatter;
  final double indicatorFraction;
  final double pixelsPerUnit;

  _VerticalWindowRulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.accentColor,
    required this.labelFormatter,
    required this.indicatorFraction,
    required this.pixelsPerUnit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * indicatorFraction;
    final rulerX = size.width * 0.75;
    final visibleHalfRange = centerY / pixelsPerUnit;
    final bandRect = Rect.fromCenter(
      center: Offset(size.width * 0.53, centerY),
      width: size.width - 26,
      height: 54,
    );

    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          accentColor.withValues(alpha: 0.04),
          accentColor.withValues(alpha: 0.14),
          accentColor.withValues(alpha: 0.06),
        ],
      ).createShader(bandRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bandRect, const Radius.circular(24)),
      bandPaint,
    );

    final spinePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rulerX, 24),
      Offset(rulerX, size.height - 24),
      spinePaint,
    );

    final startTick = math.max(
      min.floor(),
      (value - visibleHalfRange).floor() - 1,
    );
    final endTick = math.min(max.ceil(), (value + visibleHalfRange).ceil() + 1);

    for (int tick = startTick; tick <= endTick; tick++) {
      final y = centerY - ((tick - value) * pixelsPerUnit);
      if (y < 16 || y > size.height - 16) continue;

      final major = tick % 10 == 0;
      final mid = tick % 5 == 0;
      final length = major ? 56.0 : (mid ? 36.0 : 22.0);
      final tickPaint = Paint()
        ..color = major
            ? AppColors.tealDark
            : AppColors.textMuted.withValues(alpha: mid ? 0.9 : 0.7)
        ..strokeWidth = major ? 2.6 : 1.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(rulerX - length, y), Offset(rulerX, y), tickPaint);

      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: labelFormatter?.call(tick) ?? '$tick',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.tealDark,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          Offset(rulerX - length - label.width - 10, y - (label.height / 2)),
        );
      }
    }

    final whiteIndicator = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final accentIndicator = Paint()
      ..color = accentColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(18, centerY),
      Offset(size.width - 18, centerY),
      whiteIndicator,
    );
    canvas.drawLine(
      Offset(18, centerY),
      Offset(size.width - 18, centerY),
      accentIndicator,
    );

    final focusPaint = Paint()..color = accentColor;
    canvas.drawCircle(Offset(rulerX, centerY), 6.5, focusPaint);
    canvas.drawCircle(
      Offset(rulerX, centerY),
      2.6,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _VerticalWindowRulerPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.labelFormatter != labelFormatter ||
        oldDelegate.indicatorFraction != indicatorFraction ||
        oldDelegate.pixelsPerUnit != pixelsPerUnit;
  }
}

class _HorizontalWindowRulerPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final Color accentColor;
  final double pixelsPerUnit;
  final List<WindowRulerMarker> markers;

  _HorizontalWindowRulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.accentColor,
    required this.pixelsPerUnit,
    required this.markers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height * 0.76;
    final visibleHalfRange = centerX / pixelsPerUnit;
    final highlightRect = Rect.fromCenter(
      center: Offset(centerX, baseY - 28),
      width: 88,
      height: size.height - 36,
    );

    final focusPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.13),
          accentColor.withValues(alpha: 0.04),
        ],
      ).createShader(highlightRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(30)),
      focusPaint,
    );

    final baselinePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(20, baseY),
      Offset(size.width - 20, baseY),
      baselinePaint,
    );

    final startTick = math.max(
      min.floor(),
      (value - visibleHalfRange).floor() - 1,
    );
    final endTick = math.min(max.ceil(), (value + visibleHalfRange).ceil() + 1);

    for (int tick = startTick; tick <= endTick; tick++) {
      final x = centerX + ((tick - value) * pixelsPerUnit);
      if (x < 12 || x > size.width - 12) continue;

      final major = tick % 10 == 0;
      final mid = tick % 5 == 0;
      final tickHeight = major ? 48.0 : (mid ? 30.0 : 18.0);
      final tickPaint = Paint()
        ..color = major
            ? AppColors.tealDark
            : AppColors.textMuted.withValues(alpha: mid ? 0.9 : 0.7)
        ..strokeWidth = major ? 2.4 : 1.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, baseY - tickHeight),
        Offset(x, baseY),
        tickPaint,
      );

      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: '$tick',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.tealDark,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - (label.width / 2), 24));
      }
    }

    for (final marker in markers) {
      _paintMarker(canvas, size, marker, baseY, centerX);
    }

    final whiteIndicator = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final accentIndicator = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(0, 0), const Offset(0, 0), whiteIndicator);
    canvas.drawLine(
      Offset(centerX, 22),
      Offset(centerX, baseY + 12),
      whiteIndicator,
    );
    canvas.drawLine(
      Offset(centerX, 22),
      Offset(centerX, baseY + 12),
      accentIndicator,
    );

    canvas.drawCircle(
      Offset(centerX, baseY + 10),
      6,
      Paint()..color = accentColor,
    );
    canvas.drawCircle(
      Offset(centerX, baseY + 10),
      2.5,
      Paint()..color = Colors.white,
    );
  }

  void _paintMarker(
    Canvas canvas,
    Size size,
    WindowRulerMarker marker,
    double baseY,
    double centerX,
  ) {
    final rawX = centerX + ((marker.value - value) * pixelsPerUnit);
    final x = rawX.clamp(28.0, size.width - 28.0);
    final chipText = TextPainter(
      text: TextSpan(
        text: marker.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: marker.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, 30),
        width: chipText.width + 20,
        height: 28,
      ),
      const Radius.circular(14),
    );

    final fillPaint = Paint()..color = marker.color.withValues(alpha: 0.12);
    final borderPaint = Paint()
      ..color = marker.color.withValues(alpha: 0.22)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = marker.color.withValues(alpha: 0.75)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(chipRect, fillPaint);
    canvas.drawRRect(chipRect, borderPaint);
    chipText.paint(
      canvas,
      Offset(x - (chipText.width / 2), 30 - (chipText.height / 2)),
    );

    canvas.drawLine(Offset(x, 48), Offset(x, baseY - 8), linePaint);
    canvas.drawCircle(Offset(x, baseY), 4.5, Paint()..color = marker.color);
  }

  @override
  bool shouldRepaint(covariant _HorizontalWindowRulerPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.pixelsPerUnit != pixelsPerUnit ||
        oldDelegate.markers != markers;
  }
}
