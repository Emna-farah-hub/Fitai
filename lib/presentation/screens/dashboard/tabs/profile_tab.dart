import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';

/// Profile tab — shows user info, stats, health & goals, and sign out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, AuthProvider>(
      builder: (context, userProvider, authProvider, _) {
        final profile = userProvider.profile;
        final email = authProvider.currentUser?.email ?? '';
        final name = profile?.name ?? 'User';

        if (profile == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        // BMI calculation
        final heightM = profile.height / 100;
        final bmi = profile.weight / (heightM * heightM);
        String bmiCategory;
        Color bmiColor;
        if (bmi < 18.5) {
          bmiCategory = 'Underweight';
          bmiColor = AppColors.macroCarbs;
        } else if (bmi < 25) {
          bmiCategory = 'Normal';
          bmiColor = AppColors.primary;
        } else if (bmi < 30) {
          bmiCategory = 'Overweight';
          bmiColor = AppColors.warning;
        } else {
          bmiCategory = 'Obese';
          bmiColor = AppColors.error;
        }

        return SingleChildScrollView(
            child: Column(
              children: [
                // Green gradient header
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 20),

                // Stats cards row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.speed_rounded,
                          iconColor: bmiColor,
                          label: 'BMI',
                          value: bmi.toStringAsFixed(1),
                          subtitle: bmiCategory,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.favorite_rounded,
                          iconColor: const Color(0xFFf43f5e),
                          label: 'BMR',
                          value: '${profile.bmr.round()}',
                          subtitle: 'kcal/day',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.track_changes_rounded,
                          iconColor: AppColors.primary,
                          label: 'Target',
                          value: '${profile.dailyCalorieGoal}',
                          subtitle: 'kcal/day',
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 20),

                // Personal Info card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionCard(
                    title: 'Personal Information',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Age', value: '${profile.age} years'),
                        const Divider(height: 1, color: AppColors.divider),
                        _InfoRow(label: 'Height', value: '${profile.height.round()} cm'),
                        const Divider(height: 1, color: AppColors.divider),
                        _InfoRow(label: 'Weight', value: '${profile.weight.round()} kg'),
                        const Divider(height: 1, color: AppColors.divider),
                        _InfoRow(label: 'Sex', value: profile.sex == 'male' ? 'Male' : 'Female'),
                        const Divider(height: 1, color: AppColors.divider),
                        _InfoRow(label: 'Activity', value: profile.activityLevel),
                        const Divider(height: 1, color: AppColors.divider),
                        _InfoRow(label: 'Fitness', value: profile.fitnessLevel),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 16),

                // Health & Goals card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionCard(
                    title: 'Health & Goals',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.conditions
                              .map((c) => _PillChip(label: c))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Goals',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.goals
                              .map((g) => _PillChip(label: g))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Diet',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PillChip(label: profile.dietaryPreference),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 24),

                // Sign Out button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.read<AuthProvider>().signOut();
                        if (context.mounted) {
                          context.read<UserProvider>().clearProfile();
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        'Sign Out',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms),

                const SizedBox(height: 32),
              ],
            ),
          );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;

  const _PillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
