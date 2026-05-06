import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../agent/tools/agent_tools.dart';
import '../core/constants/app_colors.dart';

class WeeklyInsightsScreen extends StatefulWidget {
  const WeeklyInsightsScreen({super.key});

  @override
  State<WeeklyInsightsScreen> createState() => _WeeklyInsightsScreenState();
}

class _WeeklyInsightsScreenState extends State<WeeklyInsightsScreen> {
  final _db = FirebaseFirestore.instance;
  final _tools = AgentTools();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  bool _isLoading = true;

  Map<String, dynamic> _weekly = {};
  Map<String, dynamic>? _plan;
  List<Map<String, dynamic>> _agentActions = [];
  Map<String, double> _tagScores = {};
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _tools.getWeeklyHistory(_uid),
        _db.collection('meal_plan').doc(_uid).get(),
        _db
            .collection('agent_actions')
            .doc(_uid)
            .collection('log')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get(),
        _db.collection('preferences').doc(_uid).get(),
        _db.collection('users').doc(_uid).get(),
      ]);

      final weekly = results[0] as Map<String, dynamic>;
      final planSnap = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final actionsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final prefSnap = results[3] as DocumentSnapshot<Map<String, dynamic>>;
      final userSnap = results[4] as DocumentSnapshot<Map<String, dynamic>>;

      final rawTags =
          prefSnap.data()?['tagScores'] as Map<String, dynamic>? ?? {};
      final tagScores = <String, double>{
        for (final e in rawTags.entries) e.key: (e.value as num).toDouble(),
      };

      if (!mounted) return;
      setState(() {
        _weekly = weekly;
        _plan = planSnap.exists ? planSnap.data() : null;
        _agentActions =
            actionsSnap.docs.map((d) => d.data()).toList(growable: false);
        _tagScores = tagScores;
        _user = userSnap.exists ? userSnap.data() : null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Plan-derived stats ────────────────────────────────

  ({int total, int confirmed, int swapped, Map<String, int> confirmedByType})
      _planStats() {
    final counts = {'breakfast': 0, 'lunch': 0, 'dinner': 0, 'snack': 0};
    int total = 0, confirmed = 0, swapped = 0;
    final days = _plan?['days'] as Map<String, dynamic>? ?? {};
    for (final dayData in days.values) {
      final day = dayData as Map<String, dynamic>;
      for (final t in const ['breakfast', 'lunch', 'dinner', 'snack']) {
        final m = day[t] as Map<String, dynamic>?;
        if (m == null) continue;
        total++;
        if (m['confirmed'] == true) {
          confirmed++;
          counts[t] = (counts[t] ?? 0) + 1;
        }
        if (m['swapped'] == true) swapped++;
      }
    }
    return (
      total: total,
      confirmed: confirmed,
      swapped: swapped,
      confirmedByType: counts,
    );
  }

  // ─── Tag helpers ───────────────────────────────────────

  List<String> _topTags({required bool liked}) {
    final entries = _tagScores.entries
        .where((e) => liked ? e.value > 0 : e.value < 0)
        .toList()
      ..sort((a, b) =>
          liked ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    return entries.take(3).map((e) => e.key).toList();
  }

  String _formatTag(String raw) {
    final parts = raw.replaceAll('_', ' ').split(' ');
    return parts
        .map((p) =>
            p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _formatActionType(String raw) => _formatTag(raw);

  // ─── Agent action helpers ──────────────────────────────

  int _countActionsOfType(String type) =>
      _agentActions.where((a) => a['type'] == type).length;

  String _formatActionTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    if (isToday) {
      return DateFormat('h:mm a').format(dt);
    }
    final daysAgo = now.difference(dt).inDays;
    if (daysAgo < 7) {
      return DateFormat('EEE').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }

  // ─── BUILD ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  _buildAppBar(),
                  Expanded(child: _buildBody()),
                ],
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Weekly Insights',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final stats = _planStats();
    final daysLogged = (_weekly['daysLogged'] ?? 0) as int;
    final consistencyScore = (_weekly['consistencyScore'] ?? 0) as int;
    final mostSkipped = (_weekly['mostSkippedMealType'] ?? '') as String;
    final avgCal = ((_weekly['averageDailyCalories'] ?? 0) as num).toDouble();

    final adherence = stats.total == 0
        ? 0
        : ((stats.confirmed / stats.total) * 100).round();

    final currentTarget = (_plan?['dailyCalorieTarget'] ?? 0) as num;
    final originalTarget = (_user?['dailyCalorieGoal'] ?? 0) as num;
    final calorieAdaptCount = _countActionsOfType('calorie_target_updated');

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _heroCard(
          adherencePercent: adherence,
          consistencyScore: consistencyScore,
          daysLogged: daysLogged,
          confirmedMeals: stats.confirmed,
          swappedMeals: stats.swapped,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 0.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 12),
        _calorieSection(
          avgCal: avgCal,
          currentTarget: currentTarget.toInt(),
          originalTarget: originalTarget.toInt(),
          adapted: calorieAdaptCount > 0,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 100.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 12),
        _mealPatternsSection(
          confirmedByType: stats.confirmedByType,
          mostSkipped: mostSkipped,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 12),
        _tasteProfileSection()
            .animate()
            .fadeIn(duration: 400.ms, delay: 300.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 12),
        _agentActivitySection()
            .animate()
            .fadeIn(duration: 400.ms, delay: 400.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── HERO ──────────────────────────────────────────────

  Widget _heroCard({
    required int adherencePercent,
    required int consistencyScore,
    required int daysLogged,
    required int confirmedMeals,
    required int swappedMeals,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Consistency $consistencyScore%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$adherencePercent%',
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of your meals eaten',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _heroStat('$daysLogged/7', 'days logged'),
              _heroStat('$confirmedMeals', 'meals eaten'),
              _heroStat('$swappedMeals', 'swapped'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ─── CALORIE TRACKING ──────────────────────────────────

  Widget _calorieSection({
    required double avgCal,
    required int currentTarget,
    required int originalTarget,
    required bool adapted,
  }) {
    final safeTarget = currentTarget == 0 ? 1 : currentTarget;
    String trendLabel;
    Color trendColor;
    if (avgCal < safeTarget * 0.85) {
      trendLabel = '↓ Under';
      trendColor = const Color(0xFFF59E0B);
    } else if (avgCal > safeTarget * 1.15) {
      trendLabel = '↑ Over';
      trendColor = const Color(0xFFEF4444);
    } else {
      trendLabel = '✓ On track';
      trendColor = AppColors.primary;
    }

    return _sectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Calorie Tracking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  value: '${avgCal.round()}',
                  label: 'avg/day',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  value: '$currentTarget',
                  label: 'current target',
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  value: trendLabel,
                  label: 'vs target',
                  color: trendColor,
                ),
              ),
            ],
          ),
          if (adapted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your target was adapted this week based on your eating patterns',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricTile({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
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
        ],
      ),
    );
  }

  // ─── MEAL PATTERNS ─────────────────────────────────────

  Widget _mealPatternsSection({
    required Map<String, int> confirmedByType,
    required String mostSkipped,
  }) {
    const types = [
      ('Breakfast', 'breakfast', '🍳'),
      ('Lunch', 'lunch', '🥗'),
      ('Dinner', 'dinner', '🍽️'),
      ('Snack', 'snack', '🍎'),
    ];

    return _sectionCard(
      icon: Icons.restaurant_rounded,
      title: 'Meal Patterns',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < types.length; i++) ...[
            _mealPatternRow(
              emoji: types[i].$3,
              name: types[i].$1,
              count: confirmedByType[types[i].$2] ?? 0,
            ),
            if (i < types.length - 1) const SizedBox(height: 8),
          ],
          if (mostSkipped.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You skipped $mostSkipped most often — '
                      "next week's plan has been adjusted with quicker options",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mealPatternRow({
    required String emoji,
    required String name,
    required int count,
  }) {
    Color barColor;
    if (count >= 5) {
      barColor = AppColors.primary;
    } else if (count >= 3) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = const Color(0xFFEF4444);
    }
    final ratio = (count / 7).clamp(0.0, 1.0);

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          width: 80,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count/7',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── TASTE PROFILE ─────────────────────────────────────

  Widget _tasteProfileSection() {
    final liked = _topTags(liked: true);
    final disliked = _topTags(liked: false);

    return _sectionCard(
      icon: Icons.favorite_rounded,
      title: 'Your Taste Profile',
      child: (liked.isEmpty && disliked.isEmpty)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Swipe more meals to build your taste profile',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'You love',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      for (final tag in liked)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite,
                                  color: AppColors.primary, size: 12),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _formatTag(tag),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Less preferred',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      for (final tag in disliked)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close,
                                  color: Color(0xFFEF4444), size: 12),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _formatTag(tag),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ─── AGENT ACTIVITY ────────────────────────────────────

  Widget _agentActivitySection() {
    final actions = _agentActions.take(5).toList();
    return _sectionCard(
      icon: Icons.auto_awesome,
      title: 'Agent Activity This Week',
      child: actions.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No agent activity recorded yet',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  _agentActivityRow(actions[i]),
                  if (i < actions.length - 1)
                    const Divider(height: 1, color: AppColors.divider),
                ],
              ],
            ),
    );
  }

  Widget _agentActivityRow(Map<String, dynamic> action) {
    final type = (action['type'] ?? '') as String;
    final observation = (action['observation'] ?? '') as String;
    final ts = action['timestamp'] is Timestamp
        ? action['timestamp'] as Timestamp
        : null;

    Color circleBg;
    Color iconColor;
    IconData iconData;
    switch (type) {
      case 'glycemic_alert':
        circleBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.warning_amber_rounded;
        break;
      case 'plan_generated':
        circleBg = AppColors.primarySurface;
        iconColor = AppColors.primary;
        iconData = Icons.calendar_today_rounded;
        break;
      case 'morning_briefing':
        circleBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF1D4ED8);
        iconData = Icons.wb_sunny_rounded;
        break;
      case 'calorie_target_updated':
        circleBg = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF6B21A8);
        iconData = Icons.tune_rounded;
        break;
      default:
        circleBg = AppColors.surfaceVariant;
        iconColor = AppColors.textMuted;
        iconData = Icons.auto_awesome;
    }

    final truncated = observation.length > 60
        ? '${observation.substring(0, 60)}…'
        : observation;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatActionType(type),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (truncated.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    truncated,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatActionTime(ts),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION CARD WRAPPER ──────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
