import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../agent/orchestrator.dart';
import '../core/constants/app_colors.dart';
import 'shopping_list_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _db = FirebaseFirestore.instance;
  final _orchestrator = AgentOrchestrator();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _db.collection('meal_plan').doc(_uid).get(),
        _db.collection('users').doc(_uid).get(),
      ]);
      if (!mounted) return;
      setState(() {
        _plan = results[0].exists ? results[0].data() : null;
        _user = results[1].exists ? results[1].data() : null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _planTitle() {
    final goals = List<String>.from(_user?['goals'] ?? const [])
        .map((e) => e.toLowerCase())
        .toList();
    final conditions = List<String>.from(_user?['conditions'] ?? const [])
        .map((e) => e.toLowerCase())
        .toList();
    if (conditions.any((c) => c.contains('diabet'))) {
      return 'Diabetes-Friendly Plan';
    }
    if (goals.any((g) => g.contains('lose'))) return 'Weight Loss Plan';
    if (goals.any((g) => g.contains('muscle'))) return 'Muscle Gain Plan';
    return 'Personalized Plan';
  }

  ({int confirmed, int total, int eaten}) _computeStats(
      Map<String, dynamic> days) {
    var confirmed = 0;
    var total = 0;
    for (final entry in days.values) {
      final day = entry as Map<String, dynamic>;
      for (final mt in const ['breakfast', 'lunch', 'dinner', 'snack']) {
        final meal = day[mt] as Map<String, dynamic>?;
        if (meal == null) continue;
        total++;
        if (meal['confirmed'] == true) confirmed++;
      }
    }
    return (confirmed: confirmed, total: total, eaten: confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '7-Day Meal Plan',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _plan == null
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No plan generated yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete the agent onboarding to get your plan',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final days = _plan!['days'] as Map<String, dynamic>? ?? {};
    final version = _plan!['version'] ?? 1;
    final calorieTarget = _plan!['dailyCalorieTarget'] ?? 2000;
    final dayData = days['$_selectedDay'] as Map<String, dynamic>?;
    final stats = _computeStats(days);
    final adherence = stats.total == 0
        ? 0
        : ((stats.confirmed / stats.total) * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeroCard(version, calorieTarget, adherence, stats.eaten),
        const SizedBox(height: 20),
        _buildDaySelector(days),
        const SizedBox(height: 20),
        if (dayData == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No data for this day',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          _buildTimeline(dayData),
          const SizedBox(height: 20),
          if (dayData['dailyTotal'] != null)
            _buildDailyTotalCard(
                dayData['dailyTotal'] as Map<String, dynamic>),
        ],
      ],
    );
  }

  Widget _buildHeroCard(
      dynamic version, dynamic calorieTarget, int adherence, int eaten) {
    final name = _user?['name']?.toString() ?? 'You';
    return Container(
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
      padding: const EdgeInsets.all(20),
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
                      'PERSONALIZED FOR ${name.toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _planTitle(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '~$calorieTarget kcal/day · 7 days',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$version',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('$adherence%', 'Adherence'),
              const SizedBox(width: 16),
              _heroStat('$eaten', 'Eaten'),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShoppingListScreen(),
                    ),
                  );
                },
                child: Text(
                  '🛒 Shopping',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
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
            fontSize: 11,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelector(Map<String, dynamic> days) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final dayNum = index + 1;
          final day = days['$dayNum'] as Map<String, dynamic>?;
          final isSelected = dayNum == _selectedDay;
          var label = 'D$dayNum';
          if (day != null && day['date'] is String) {
            try {
              label =
                  DateFormat('EEE').format(DateTime.parse(day['date'])).toUpperCase();
            } catch (_) {}
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = dayNum),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  width: 0.5,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                ),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dayNum',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> dayData) {
    const order = ['breakfast', 'lunch', 'dinner', 'snack'];
    final items = <Widget>[];
    for (var i = 0; i < order.length; i++) {
      final type = order[i];
      final meal = dayData[type] as Map<String, dynamic>?;
      items.add(_buildTimelineRow(
        mealType: type,
        meal: meal,
        isLast: i == order.length - 1,
        index: i,
      ));
    }
    return Column(children: items);
  }

  ({Color bg, Color accent, Color border, String emoji}) _styleFor(
      String mealType) {
    switch (mealType) {
      case 'breakfast':
        return (
          bg: const Color(0xFFFFF7ED),
          accent: const Color(0xFFC2410C),
          border: const Color(0xFFFED7AA),
          emoji: '🍳',
        );
      case 'lunch':
        return (
          bg: const Color(0xFFF0FDF4),
          accent: const Color(0xFF15803D),
          border: const Color(0xFFBBF7D0),
          emoji: '🥗',
        );
      case 'dinner':
        return (
          bg: const Color(0xFFEFF6FF),
          accent: const Color(0xFF1D4ED8),
          border: const Color(0xFFBFDBFE),
          emoji: '🍽️',
        );
      case 'snack':
      default:
        return (
          bg: const Color(0xFFFAF5FF),
          accent: const Color(0xFF6B21A8),
          border: const Color(0xFFE9D5FF),
          emoji: '🍎',
        );
    }
  }

  Widget _buildTimelineRow({
    required String mealType,
    required Map<String, dynamic>? meal,
    required bool isLast,
    required int index,
  }) {
    final style = _styleFor(mealType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: style.border, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child:
                    Text(style.emoji, style: const TextStyle(fontSize: 18)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: style.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _buildMealCard(mealType, meal, style),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 80).ms, duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildMealCard(
    String mealType,
    Map<String, dynamic>? meal,
    ({Color bg, Color accent, Color border, String emoji}) style,
  ) {
    if (meal == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: style.bg,
          border: Border.all(color: style.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              mealType.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.accent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '· Not planned',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final isConfirmed = meal['confirmed'] == true;
    final isSwapped = meal['swapped'] == true;
    final calories = meal['calories'] ?? 0;
    final protein = meal['protein'] ?? 0;
    final carbs = meal['carbs'] ?? 0;
    final fats = meal['fats'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.bg,
        border: Border.all(color: style.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                mealType.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: style.accent,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (isConfirmed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '✓ EATEN',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              if (isSwapped) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'SWAPPED',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE65100),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            meal['name']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$calories kcal · P:${protein}g C:${carbs}g F:${fats}g',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (meal['cuisine'] == 'tunisian' ||
              meal['glycemicIndex'] != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (meal['cuisine'] == 'tunisian')
                  _tagPill(
                    '🇹🇳 Tunisian',
                    bg: const Color(0xFFFEE2E2),
                    fg: const Color(0xFF991B1B),
                  ),
                if (meal['glycemicIndex'] != null)
                  _tagPill(
                    'GI:${meal['glycemicIndex']}',
                    bg: const Color(0xFFDBEAFE),
                    fg: const Color(0xFF1E40AF),
                  ),
              ],
            ),
          ],
          if (!isConfirmed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _markEaten(mealType),
                    child: Text(
                      'I ate this',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: style.accent,
                    side: BorderSide(color: style.accent.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showSwapSheet(mealType),
                  child: Text(
                    '↻ Swap',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tagPill(String label, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDailyTotalCard(Map<String, dynamic> total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY TOTAL',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _totalStat('${total['calories'] ?? 0}', 'kcal',
                  AppColors.primary),
              _totalStat('${total['protein'] ?? 0}g', 'protein',
                  const Color(0xFFEF4444)),
              _totalStat('${total['carbs'] ?? 0}g', 'carbs',
                  const Color(0xFF3B82F6)),
              _totalStat('${total['fats'] ?? 0}g', 'fats',
                  const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _markEaten(String mealType) async {
    try {
      final planDoc = await _db.collection('meal_plan').doc(_uid).get();
      if (!planDoc.exists) return;
      final days = Map<String, dynamic>.from(planDoc.data()?['days'] ?? {});
      final day = Map<String, dynamic>.from(days['$_selectedDay'] ?? {});
      final meal = Map<String, dynamic>.from(day[mealType] ?? {});
      if (meal.isEmpty) return;

      meal['confirmed'] = true;
      day[mealType] = meal;
      days['$_selectedDay'] = day;

      await _db.collection('meal_plan').doc(_uid).update({'days': days});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ ${meal['name']} marked as eaten',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      _loadAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm meal')),
      );
    }
  }

  void _showSwapSheet(String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SwapSheet(
        uid: _uid,
        dayNumber: _selectedDay,
        mealType: mealType,
        orchestrator: _orchestrator,
        onSwapped: () {
          Navigator.pop(ctx);
          _loadAll();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Meal swapped! ↻',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }
}

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({
    required this.uid,
    required this.dayNumber,
    required this.mealType,
    required this.orchestrator,
    required this.onSwapped,
  });

  final String uid;
  final int dayNumber;
  final String mealType;
  final AgentOrchestrator orchestrator;
  final VoidCallback onSwapped;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  bool _isLoading = true;
  bool _isSwapping = false;
  List<Map<String, dynamic>> _alternatives = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.orchestrator.getSwapAlternatives(
      uid: widget.uid,
      dayNumber: widget.dayNumber,
      mealType: widget.mealType,
    );
    if (!mounted) return;
    setState(() {
      _alternatives = list;
      _isLoading = false;
    });
  }

  Future<void> _choose(Map<String, dynamic> alternative) async {
    if (_isSwapping) return;
    setState(() => _isSwapping = true);
    await widget.orchestrator.confirmSwap(
      uid: widget.uid,
      dayNumber: widget.dayNumber,
      mealType: widget.mealType,
      chosenMeal: alternative,
    );
    if (!mounted) return;
    widget.onSwapped();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Swap ${widget.mealType}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_alternatives.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'No alternatives available right now',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _alternatives.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alt = _alternatives[index];
        return _alternativeCard(alt, index);
      },
    );
  }

  Widget _alternativeCard(Map<String, dynamic> meal, int index) {
    final calories = meal['calories'] ?? 0;
    final protein = meal['protein'] ?? 0;
    final carbs = meal['carbs'] ?? 0;
    final fats = meal['fats'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal['name']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$calories kcal · P:${protein}g C:${carbs}g F:${fats}g',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (meal['cuisine'] == 'tunisian') ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🇹🇳 Tunisian',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSwapping ? null : () => _choose(meal),
              child: Text(
                'Choose this',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 350.ms)
        .slideY(begin: 0.05, end: 0);
  }
}
