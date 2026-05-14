import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// A full-width button with the app's signature green gradient.
/// Used for primary CTAs throughout the app.
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? trailingIcon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  bool get _isInteractive => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_isInteractive || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.96 : 1.0;
    final shadowBlur = _isPressed ? 4.0 : 12.0;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _isInteractive
            ? (_) {
                setState(() => _isPressed = true);
                HapticFeedback.lightImpact();
              }
            : null,
        onTapUp: _isInteractive ? (_) => _setPressed(false) : null,
        onTapCancel: _isInteractive ? () => _setPressed(false) : null,
        onTap: _isInteractive ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _isPressed ? 80 : 200),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(scale, scale, 1),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.onPressed != null
                ? AppColors.buttonGradient
                : const LinearGradient(
                    colors: [AppColors.border, AppColors.border],
                  ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: widget.onPressed != null
                ? [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: shadowBlur,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: widget.isLoading ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: _ButtonContent(
                  label: widget.label,
                  trailingIcon: widget.trailingIcon,
                ),
              ),
              AnimatedOpacity(
                opacity: widget.isLoading ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: const _LoadingDots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;

  const _ButtonContent({required this.label, required this.trailingIcon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, color: Colors.white, size: 18),
        ],
      ],
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          _LoadingDot(delay: Duration(milliseconds: i * 100)),
          if (i < 2) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _LoadingDot extends StatelessWidget {
  final Duration delay;

  const _LoadingDot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .moveY(
          begin: 0,
          end: -6,
          duration: 320.ms,
          delay: delay,
          curve: Curves.easeOut,
        )
        .then()
        .moveY(begin: -6, end: 0, duration: 320.ms, curve: Curves.easeOut);
  }
}
