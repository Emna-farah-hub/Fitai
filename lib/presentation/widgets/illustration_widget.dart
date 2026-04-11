import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';

/// A reusable illustration widget that renders an SVG asset with animations.
/// Falls back to a gradient container with an icon if the SVG fails to load.
class IllustrationWidget extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final double height;

  const IllustrationWidget({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return _SvgWithFallback(
      assetPath: assetPath,
      fallbackIcon: fallbackIcon,
      height: height,
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.05, end: 0)
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 3000.ms, curve: Curves.easeInOut);
  }
}

class _SvgWithFallback extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final double height;

  const _SvgWithFallback({
    required this.assetPath,
    required this.fallbackIcon,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      height: height,
      placeholderBuilder: (_) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: height * 0.6,
      height: height * 0.6,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        fallbackIcon,
        color: Colors.white,
        size: 48,
      ),
    );
  }
}
