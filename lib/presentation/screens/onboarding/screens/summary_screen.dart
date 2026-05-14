import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../widgets/onboarding_progress_bar.dart';
import '../../../widgets/press_scale.dart';

const Color _summaryBg = AppColors.backgroundAlt;
const Color _summaryCard = AppColors.surface;
const Color _summaryCardSoft = AppColors.surfaceSoft;
const Color _summaryText = AppColors.textPrimary;
const Color _summaryMuted = AppColors.textSecondary;
const Color _summaryAccent = AppColors.primary;
const Color _summaryAccentDeep = AppColors.tealDark;

class SummaryScreen extends StatefulWidget {
  final VoidCallback onNext;

  const SummaryScreen({super.key, required this.onNext});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OnboardingProvider>().calculatePlan();
  }

  int _months(OnboardingProvider provider) {
    final rate = switch (provider.resultPace) {
      'gradual' => 0.8,
      'ambitious' => 3.0,
      _ => 1.7,
    };
    final loss = math.max(0.0, provider.weightKg - provider.targetWeightKg);
    return loss <= 0 ? 0 : (loss / rate).ceil();
  }

  String _targetDate(int months) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month + months, 1);
    const names = [
      'Jan',
      'Fev',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aout',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  double _bmi(OnboardingProvider provider) {
    final meters = provider.heightCm / 100;
    return provider.weightKg / (meters * meters);
  }

  _BmiStatus _bmiStatus(double bmi) {
    if (bmi < 18.5) {
      return const _BmiStatus(
        label: 'Poids insuffisant',
        tone: AppColors.amberDark,
        fill: AppColors.amberSoft,
        helper:
            'Votre plan veillera a renforcer vos apports pour progresser de facon stable.',
      );
    }
    if (bmi < 25) {
      return const _BmiStatus(
        label: 'Poids normal',
        tone: AppColors.primaryDark,
        fill: AppColors.primarySoft,
        helper:
            'Votre IMC se situe dans la zone recommandee pour construire des habitudes durables.',
      );
    }
    if (bmi < 30) {
      return const _BmiStatus(
        label: 'Leger surpoids',
        tone: AppColors.amberDark,
        fill: AppColors.amberSoft,
        helper:
            'Votre plan privilegie un rythme realiste pour vous rapprocher de votre zone cible.',
      );
    }
    return const _BmiStatus(
      label: 'A surveiller',
      tone: AppColors.error,
      fill: AppColors.errorSurface,
      helper:
          'Votre programme donnera la priorite a la regularite, au deficit adapte et a la progression.',
    );
  }

  String _goalLabel(String goal) {
    switch (goal.toLowerCase()) {
      case 'lose weight':
        return 'Perdre du poids';
      case 'gain muscle':
        return 'Prendre du muscle';
      case 'maintain weight':
        return 'Maintenir mon poids';
      case 'feel better':
        return 'Me sentir mieux';
      default:
        return goal;
    }
  }

  String _activityLabel(String activity) {
    switch (activity.toLowerCase()) {
      case 'sedentary':
        return 'Sedentaire';
      case 'lightly active':
        return 'Activite legere';
      case 'moderately active':
        return 'Activite moyenne';
      case 'very active':
        return 'Tres actif';
      default:
        return activity;
    }
  }

  String _paceLabel(String pace) {
    switch (pace.toLowerCase()) {
      case 'gradual':
        return 'Progressif';
      case 'ambitious':
        return 'Ambitieux';
      default:
        return 'Equilibre';
    }
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'VP';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'VP' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final calories = provider.dailyCalorieGoal > 0
        ? provider.dailyCalorieGoal
        : provider.tdee.round();
    final months = _months(provider);
    final bmi = _bmi(provider);
    final bmiStatus = _bmiStatus(bmi);
    final cuisines = provider.favoriteCuisines.isEmpty
        ? 'Cuisine flexible'
        : provider.favoriteCuisines.take(2).join('  •  ');

    return Scaffold(
      backgroundColor: _summaryBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            const OnboardingProgressBar(
              currentSection: 5,
              progressInSection: 0.75,
              accentColor: _summaryAccent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryHeader(
                          initials: _initials(provider.name),
                          name: provider.name,
                        )
                        .animate()
                        .fadeIn(duration: 260.ms)
                        .slideY(begin: 0.08, end: 0, duration: 260.ms),
                    const SizedBox(height: 22),
                    _BmiSummaryCard(
                          bmi: bmi,
                          status: bmiStatus,
                          weightKg: provider.weightKg,
                        )
                        .animate()
                        .fadeIn(duration: 320.ms, delay: 120.ms)
                        .slideY(
                          begin: 0.10,
                          end: 0,
                          duration: 320.ms,
                          delay: 120.ms,
                        ),
                    const SizedBox(height: 14),
                    _StatsGrid(
                          cards: [
                            _StatCardData(
                              icon: Icons.flag_rounded,
                              label: 'Objectif',
                              value: _goalLabel(
                                provider.primaryGoal ?? 'Feel better',
                              ),
                            ),
                            _StatCardData(
                              icon: Icons.track_changes_rounded,
                              label: 'Poids cible',
                              value: '${provider.targetWeightKg.round()} kg',
                            ),
                            _StatCardData(
                              icon: Icons.directions_walk_rounded,
                              label: "Niveau d'activite",
                              value: _activityLabel(provider.activityLevel),
                            ),
                            _StatCardData(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Cible calorique',
                              value: '$calories kcal',
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 320.ms, delay: 220.ms)
                        .slideY(
                          begin: 0.10,
                          end: 0,
                          duration: 320.ms,
                          delay: 220.ms,
                        ),
                    const SizedBox(height: 14),
                    _IllustrationCard(
                          goalLabel: _goalLabel(
                            provider.primaryGoal ?? 'Feel better',
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 320.ms, delay: 320.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 320.ms,
                          delay: 320.ms,
                        ),
                    const SizedBox(height: 14),
                    _PlanDetailsCard(
                          calories: calories,
                          protein: provider.proteinGrams,
                          fat: provider.fatGrams,
                          carbs: provider.carbGrams,
                          pace: _paceLabel(provider.resultPace),
                          targetDate: _targetDate(months),
                          cuisines: cuisines,
                          months: months,
                        )
                        .animate()
                        .fadeIn(duration: 320.ms, delay: 420.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 320.ms,
                          delay: 420.ms,
                        ),
                  ],
                ),
              ),
            ),
            _BottomCta(onPressed: widget.onNext),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final String initials;
  final String name;

  const _SummaryHeader({required this.initials, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre resume personnalise',
                style: GoogleFonts.nunito(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  color: _summaryText,
                  height: 1.02,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Concu pour vous aider a atteindre vos objectifs.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _summaryMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceSoft,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _summaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: _summaryAccentDeep,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BmiSummaryCard extends StatelessWidget {
  final double bmi;
  final _BmiStatus status;
  final double weightKg;

  const _BmiSummaryCard({
    required this.bmi,
    required this.status,
    required this.weightKg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indice de masse corporelle (IMC)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _summaryMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: status.fill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: status.tone,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    bmi.toStringAsFixed(0),
                    style: GoogleFonts.nunito(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: _summaryAccentDeep,
                      height: 0.92,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${weightKg.round()} kg actuellement',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _summaryMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _BmiRangeBar(bmi: bmi, accent: status.tone),
          const SizedBox(height: 14),
          Text(
            status.helper,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _summaryMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiRangeBar extends StatelessWidget {
  final double bmi;
  final Color accent;

  const _BmiRangeBar({required this.bmi, required this.accent});

  @override
  Widget build(BuildContext context) {
    final indicator = ((bmi - 14) / 21).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pinLeft = (constraints.maxWidth - 18) * indicator;

        return SizedBox(
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: pinLeft,
                child: Column(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 10,
                      color: accent.withValues(alpha: 0.48),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 26,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 20,
                              child: ColoredBox(color: AppColors.amberSoft),
                            ),
                            Expanded(
                              flex: 30,
                              child: ColoredBox(color: AppColors.primarySoft),
                            ),
                            Expanded(
                              flex: 25,
                              child: ColoredBox(color: AppColors.amber),
                            ),
                            Expanded(
                              flex: 25,
                              child: ColoredBox(color: AppColors.errorSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _RangeLabel(label: '18.5', alignment: TextAlign.left),
                        const Spacer(),
                        _RangeLabel(label: '25', alignment: TextAlign.center),
                        const Spacer(),
                        _RangeLabel(label: '30+', alignment: TextAlign.right),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RangeLabel extends StatelessWidget {
  final String label;
  final TextAlign alignment;

  const _RangeLabel({required this.label, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        label,
        textAlign: alignment,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _summaryMuted,
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatCardData> cards;

  const _StatsGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _StatCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        color: _summaryCardSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: _summaryAccentDeep, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _summaryMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.value,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _summaryText,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  final String goalLabel;

  const _IllustrationCard({required this.goalLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projection visuelle',
            style: GoogleFonts.nunito(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _summaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Une vue claire de votre point de depart pour $goalLabel.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _summaryMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 216,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primarySurface, AppColors.surfaceSoft],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 18,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _summaryAccent.withValues(alpha: 0.16),
                          _summaryAccent.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  child: Image.asset(
                    'assets/illustrations/silhouette_green.png',
                    height: 206,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PlanDetailsCard extends StatelessWidget {
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final String pace;
  final String targetDate;
  final String cuisines;
  final int months;

  const _PlanDetailsCard({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.pace,
    required this.targetDate,
    required this.cuisines,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: _summaryAccentDeep,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apercu de votre plan',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories',
                style: GoogleFonts.nunito(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 0.94,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'kcal / jour',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroMetric(
                  label: 'Proteines',
                  value: protein,
                  tint: AppColors.macroProtein,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroMetric(
                  label: 'Lipides',
                  value: fat,
                  tint: AppColors.macroFats,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroMetric(
                  label: 'Glucides',
                  value: carbs,
                  tint: AppColors.macroCarbs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.schedule_rounded, text: 'Rythme $pace'),
              _InfoPill(
                icon: Icons.flag_rounded,
                text: months > 0
                    ? 'Objectif vers $targetDate'
                    : 'Depart immediat',
              ),
              _InfoPill(icon: Icons.restaurant_menu_rounded, text: cuisines),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color tint;

  const _MacroMetric({
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(height: 12),
          Text(
            '$value g',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.84)),
          const SizedBox(width: 7),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  final VoidCallback onPressed;

  const _BottomCta({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset + 18),
      decoration: BoxDecoration(
        color: _summaryBg.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 24,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: PressScale(
        onPressed: onPressed,
        pressedScale: 0.975,
        invokeDelay: const Duration(milliseconds: 50),
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _summaryAccentDeep,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _summaryAccentDeep.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Commencer mon parcours →',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BmiStatus {
  final String label;
  final Color tone;
  final Color fill;
  final String helper;

  const _BmiStatus({
    required this.label,
    required this.tone,
    required this.fill,
    required this.helper,
  });
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: _summaryCard,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
    boxShadow: [
      BoxShadow(
        color: AppColors.cardShadow,
        blurRadius: 26,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.4),
        blurRadius: 0,
        offset: const Offset(0, 1),
      ),
    ],
  );
}
