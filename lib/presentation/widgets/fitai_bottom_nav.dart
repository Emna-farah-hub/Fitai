import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

/// Tab definition for [FitAIBottomNav].
class FitAINavTab {
  final IconData icon;
  final String label;

  const FitAINavTab({required this.icon, required this.label});
}

/// Floating pill-style bottom navigation for FitAI's main shell.
///
/// Tabs are passed in by the parent so the widget stays presentational —
/// active state is driven by [currentIndex] and changes are reported via
/// [onTabSelected]. Each tap fires a selection haptic.
class FitAIBottomNav extends StatelessWidget {
  final List<FitAINavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FitAIBottomNav({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < tabs.length; i++)
                _NavItem(
                  tab: tabs[i],
                  isActive: i == currentIndex,
                  onTap: () {
                    if (i == currentIndex) return;
                    HapticFeedback.selectionClick();
                    onTabSelected(i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final FitAINavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 24,
              color: isActive ? AppColors.primary : const Color(0xFF444444),
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
