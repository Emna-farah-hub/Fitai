import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class MealLoggedOverlay extends StatefulWidget {
  const MealLoggedOverlay({
    super.key,
    required this.foodName,
    required this.calories,
    required this.previousTotal,
    required this.dailyTarget,
    required this.onDismissed,
  });

  final String foodName;
  final double calories;
  final double previousTotal;
  final double dailyTarget;
  final VoidCallback onDismissed;

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String foodName,
    required double calories,
    required double previousTotal,
    required double dailyTarget,
  }) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => MealLoggedOverlay(
        foodName: foodName,
        calories: calories,
        previousTotal: previousTotal,
        dailyTarget: dailyTarget,
        onDismissed: () {
          if (_activeEntry == entry) _activeEntry = null;
          entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlayState.insert(entry);
  }

  @override
  State<MealLoggedOverlay> createState() => _MealLoggedOverlayState();
}

class _MealLoggedOverlayState extends State<MealLoggedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;
  Timer? _dismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 1.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Curves.elasticOut,
            reverseCurve: Curves.easeIn,
          ),
        );

    final safeTarget = widget.dailyTarget <= 0 ? 1.0 : widget.dailyTarget;
    final beginRatio = (widget.previousTotal / safeTarget).clamp(0.0, 1.0);
    final endRatio = ((widget.previousTotal + widget.calories) / safeTarget)
        .clamp(0.0, 1.0);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnimation = Tween<double>(begin: beginRatio, end: endRatio)
        .animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ),
        );

    HapticFeedback.mediumImpact();
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _progressController.forward();
    });

    _dismissTimer = Timer(const Duration(milliseconds: 2500), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _dismissTimer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    await _slideController.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: mediaQuery.padding.bottom + 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryBorder),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowMedium,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.foodName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${widget.calories.round()} kcal logged',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(widget.previousTotal + widget.calories).round()}'
                        ' / ${widget.dailyTarget.round()}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (_, _) => LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
