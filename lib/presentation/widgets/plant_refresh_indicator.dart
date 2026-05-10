import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class PlantRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const PlantRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<PlantRefreshIndicator> createState() => _PlantRefreshIndicatorState();
}

class _PlantRefreshIndicatorState extends State<PlantRefreshIndicator>
    with TickerProviderStateMixin {
  static const double _triggerDistance = 60;
  static const double _maxShootHeight = 40;

  late final ScrollController _scrollController;
  late final AnimationController _bloomController;
  late final AnimationController _bounceController;
  late final AnimationController _swayController;
  late final AnimationController _hideController;
  late final Animation<double> _bounceOffset;
  late final Animation<double> _swayOffset;

  double _pullDistance = 0;
  bool _isRefreshing = false;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );

    _bounceOffset = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 4.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 100,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 4.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 100,
      ),
    ]).animate(_bounceController);
    _swayOffset = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bloomController.dispose();
    _bounceController.dispose();
    _swayController.dispose();
    _hideController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is OverscrollNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        notification.overscroll < 0) {
      _setPullDistance(_pullDistance - notification.overscroll);
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < notification.metrics.minScrollExtent) {
      _setPullDistance(
        notification.metrics.minScrollExtent - notification.metrics.pixels,
      );
    } else if (notification is ScrollEndNotification) {
      if (_pullDistance >= _triggerDistance) {
        _startRefresh();
      } else {
        _hidePlant();
      }
    }

    return false;
  }

  void _setPullDistance(double value) {
    setState(() {
      _showIndicator = true;
      _pullDistance = value.clamp(0, _triggerDistance * 1.4);
      _hideController.value = 1;
    });
  }

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _showIndicator = true;
      _pullDistance = _triggerDistance;
    });

    await _bloomController.forward(from: 0);
    await _bounceController.forward(from: 0);
    _swayController.repeat(reverse: true);

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _swayController.stop();
        await _hideController.reverse(from: 1);
      }
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _showIndicator = false;
          _pullDistance = 0;
        });
        _bloomController.reset();
        _bounceController.reset();
        _hideController.value = 1;
      }
    }
  }

  Future<void> _hidePlant() async {
    if (!_showIndicator) return;
    await _hideController.reverse(from: 1);
    if (!mounted) return;
    setState(() {
      _showIndicator = false;
      _pullDistance = 0;
    });
    _hideController.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _scrollController,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            widget.child,
            if (_showIndicator)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _bloomController,
                  _bounceController,
                  _swayController,
                  _hideController,
                ]),
                builder: (context, _) {
                  final pullProgress = (_pullDistance / _triggerDistance).clamp(
                    0.0,
                    1.0,
                  );
                  final shootHeight = _maxShootHeight * pullProgress;
                  final slideUp = (1 - _hideController.value) * -shootHeight;
                  final sway = _isRefreshing ? _swayOffset.value : 0.0;
                  final loadingOpacity = _isRefreshing
                      ? 0.65 +
                            (math.sin(_swayController.value * math.pi * 2) *
                                0.15)
                      : 1.0;

                  return Positioned(
                    top: 8 + slideUp + _bounceOffset.value,
                    child: Opacity(
                      opacity: _hideController.value * loadingOpacity,
                      child: Transform.translate(
                        offset: Offset(sway, 0),
                        child: CustomPaint(
                          size: const Size(56, 56),
                          painter: _PlantShootPainter(
                            shootHeight: shootHeight,
                            leafScale: pullProgress,
                            bloomScale: _bloomController.value,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PlantShootPainter extends CustomPainter {
  final double shootHeight;
  final double leafScale;
  final double bloomScale;

  const _PlantShootPainter({
    required this.shootHeight,
    required this.leafScale,
    required this.bloomScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shootHeight <= 0) return;

    final centerX = size.width / 2;
    final top = 6.0;
    final stemBottom = top + shootHeight;
    final stemPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, top),
      Offset(centerX, stemBottom),
      stemPaint,
    );

    _drawLeaf(
      canvas,
      center: Offset(centerX + 7, stemBottom - 4),
      scale: leafScale,
      angle: -0.55,
    );
    _drawLeaf(
      canvas,
      center: Offset(centerX - 7, stemBottom - 8),
      scale: bloomScale,
      angle: math.pi + 0.55,
    );
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset center,
    required double scale,
    required double angle,
  }) {
    if (scale <= 0) return;

    final leafPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale.clamp(0.0, 1.0));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 8),
      leafPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlantShootPainter oldDelegate) {
    return oldDelegate.shootHeight != shootHeight ||
        oldDelegate.leafScale != leafScale ||
        oldDelegate.bloomScale != bloomScale;
  }
}
