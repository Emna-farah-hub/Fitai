import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';

/// Home tab of the dashboard — upgraded Sprint 1 version.
/// Shows: greeting, AI insight, calorie ring with macros, glycemic tracker,
/// BMR/TDEE stats, goals, today's meals, and coming soon banner.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, AuthProvider>(
      builder: (context, userProvider, authProvider, _) {
        if (userProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final profile = userProvider.profile;
        final name = profile?.name ?? 'there';
        final calorieGoal = profile?.dailyCalorieGoal ?? 2000;
        final bmr = profile?.bmr ?? 0.0;
        final tdee = profile?.tdee ?? 0.0;
        final goals = profile?.goals ?? [];
        final conditions = profile?.conditions ?? [];
        final hasDiabetes = conditions.contains('Diabetes Type 1') ||
            conditions.contains('Diabetes Type 2');

        // Macro targets from calorie goal
        final proteinG = (calorieGoal * 0.30 / 4).round();
        final carbsG = (calorieGoal * 0.45 / 4).round();
        final fatsG = (calorieGoal * 0.25 / 9).round();

        int delayIndex = 0;

        return Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // 1. Header Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()},',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'F',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms),

                    const SizedBox(height: 20),

                    // 2. AI Insight Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI INSIGHT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Welcome to FitAI, $name! Log your first meal to get personalized insights.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms)
                        .slideY(begin: 0.05, end: 0),

                    const SizedBox(height: 20),

                    // 3. Calorie Ring Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircularPercentIndicator(
                            radius: 60,
                            lineWidth: 10,
                            percent: 0.0,
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: AppColors.primary,
                            backgroundColor: AppColors.border,
                            animation: true,
                            animationDuration: 800,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '0',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'of $calorieGoal kcal',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Macro progress row
                          Row(
                            children: [
                              _MacroColumn(
                                label: 'Protein',
                                value: '0g',
                                target: '${proteinG}g',
                                color: AppColors.macroProtein,
                                percent: 0.0,
                              ),
                              const SizedBox(width: 16),
                              _MacroColumn(
                                label: 'Carbs',
                                value: '0g',
                                target: '${carbsG}g',
                                color: AppColors.macroCarbs,
                                percent: 0.0,
                              ),
                              const SizedBox(width: 16),
                              _MacroColumn(
                                label: 'Fats',
                                value: '0g',
                                target: '${fatsG}g',
                                color: AppColors.macroFats,
                                percent: 0.0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms)
                        .slideY(begin: 0.05, end: 0),

                    const SizedBox(height: 16),

                    // 4. Glycemic Tracker (conditional)
                    if (hasDiabetes) ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.glycemicGreen,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Glycemic Status',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Log your first meal to see glycemic tracking',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms)
                          .slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 16),
                    ],

                    // 5. BMR / TDEE stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'BMR',
                            value: '${bmr.round()}',
                            unit: 'kcal/day',
                            icon: Icons.favorite_outline_rounded,
                            color: const Color(0xFFf43f5e),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'TDEE',
                            value: '${tdee.round()}',
                            unit: 'kcal/day',
                            icon: Icons.local_fire_department_outlined,
                            color: const Color(0xFFf97316),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms)
                        .slideY(begin: 0.05, end: 0),

                    const SizedBox(height: 20),

                    // 6. Your Goals section
                    if (goals.isNotEmpty) ...[
                      Text(
                        'Your Goals',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: goals.map((goal) => _GoalChip(goal: goal)).toList(),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms),
                      const SizedBox(height: 20),
                    ],

                    // 7. Today's Meals
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Today's meals",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '+ Add meal',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Icon(
                            Icons.restaurant_outlined,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No meals logged yet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to log your first meal',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms)
                        .slideY(begin: 0.05, end: 0),

                    const SizedBox(height: 16),

                    // 8. Coming soon banner
                    _ComingSoonBanner()
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (delayIndex++ * 100).ms),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
      },
    );
  }
}

/// Macro progress column for protein/carbs/fats.
class _MacroColumn extends StatelessWidget {
  final String label;
  final String value;
  final String target;
  final Color color;
  final double percent;

  const _MacroColumn({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of $target',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat card for BMR and TDEE metrics.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip displaying one of the user's fitness goals.
class _GoalChip extends StatelessWidget {
  final String goal;

  const _GoalChip({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            goal,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner informing the user that full features are coming in Sprint 2.
class _ComingSoonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_outlined,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'More coming in Sprint 2',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'AI chat & meal insights coming soon',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
