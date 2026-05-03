import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal_entry.dart';
import '../services/meal_journal_service.dart';
import 'food_search_screen.dart';
import 'plan_screen.dart';
import 'swipe_screen.dart';

class DailyDashboardScreen extends StatefulWidget {
  const DailyDashboardScreen({super.key});

  @override
  State<DailyDashboardScreen> createState() => _DailyDashboardScreenState();
}

class _DailyDashboardScreenState extends State<DailyDashboardScreen> {
  final _mealService = MealJournalService();
  StreamSubscription<List<MealEntry>>? _subscription;

  List<MealEntry> _todayMeals = [];
  double _dailyCalorieTarget = 1800;
  List<String> _goals = [];
  List<String> _conditions = [];
  bool _isLoadingProfile = true;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  double get _totalCalories =>
      _todayMeals.fold(0.0, (sum, m) => sum + m.calories);
  double get _totalProtein =>
      _todayMeals.fold(0.0, (sum, m) => sum + m.protein);
  double get _totalCarbs => _todayMeals.fold(0.0, (sum, m) => sum + m.carbs);
  double get _totalFats => _todayMeals.fold(0.0, (sum, m) => sum + m.fats);

  double get _remaining =>
      (_dailyCalorieTarget - _totalCalories).clamp(0, double.infinity);

  int get _nutritionalScore => _mealService.calculateNutritionalScore(
        totalCalories: _totalCalories,
        totalProtein: _totalProtein,
        totalCarbs: _totalCarbs,
        totalFats: _totalFats,
        dailyCalorieTarget: _dailyCalorieTarget,
      );

  bool get _isDiabetes =>
      _goals.any((g) => g.toLowerCase().contains('diabetes')) ||
      _conditions.any((c) => c.toLowerCase().contains('diabetes'));

  double get _proteinTarget => _dailyCalorieTarget * 0.25 / 4;
  double get _carbsTarget => _dailyCalorieTarget * 0.50 / 4;
  double get _fatsTarget => _dailyCalorieTarget * 0.25 / 9;

  // Meal section config
  static const _mealSections = [
    ('Breakfast', Icons.free_breakfast, Color(0xFFFF8F00)),
    ('Lunch', Icons.lunch_dining, Color(0xFF2E7D32)),
    ('Dinner', Icons.dinner_dining, Color(0xFF1565C0)),
    ('Snack', Icons.cookie, Color(0xFF6A1B9A)),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscription = _mealService.watchTodayMeals(_uid).listen((meals) {
      if (mounted) setState(() => _todayMeals = meals);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _dailyCalorieTarget =
              (data['dailyCalorieGoal'] ?? 1800).toDouble();
          if (_dailyCalorieTarget == 0) _dailyCalorieTarget = 1800;
          _goals = List<String>.from(data['goals'] ?? []);
          _conditions = List<String>.from(data['conditions'] ?? []);
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning \u{1F305}';
    if (hour < 17) return 'Good afternoon \u{2600}\u{FE0F}';
    return 'Good evening \u{1F319}';
  }

  List<MealEntry> _mealsForType(String type) {
    return _todayMeals
        .where((m) => m.mealType.toLowerCase() == type.toLowerCase())
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _showMealTypeSheet(String mealType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MealTypeBottomSheet(
        mealType: mealType,
        onSearchTap: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoodSearchScreen(mealType: mealType),
            ),
          );
        },
        onPhotoTap: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo logging coming soon'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteMeal(MealEntry meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this meal?'),
        content: Text('Delete "${meal.foodName}" from today\'s log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _mealService.deleteMeal(_uid, meal.date, meal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Today's Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAgentCard(),
            _buildDiscoverMealsCard(),
            _buildHeader(),
            _buildCalorieRing(),
            const SizedBox(height: 12),
            _buildMacroBars(),
            const SizedBox(height: 12),
            _buildNutritionalScore(),
            const SizedBox(height: 16),
            // Meal diary sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                "Today's Meals",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            for (final section in _mealSections) ...[
              _buildMealSection(section.$1, section.$2, section.$3),
              const SizedBox(height: 12),
            ],
            _buildSuggestionSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMealTypeSheet('Lunch'),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ─── DISCOVER MEALS CARD ───────────────────────────────────

  Widget _buildDiscoverMealsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SwipeScreen(isOnboarding: false),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16a34a), Color(0xFF22c55e)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.swipe, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discover Meals',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Swipe to refine your preferences',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── AGENT CARD & SUGGESTION ───────────────────────────────

  Widget _buildAgentCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dashboard_pins')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['dismissed'] == true) {
          return const SizedBox.shrink();
        }

        final message = data['message'] as String? ?? '';
        final type = data['type'] as String? ?? '';
        final severity = data['severity'] as String? ?? 'info';

        Color accentColor;
        IconData icon;
        if (severity == 'warning') {
          accentColor = const Color(0xFFFF9800);
          icon = Icons.warning_amber_rounded;
        } else if (severity == 'success') {
          accentColor = const Color(0xFF4CAF50);
          icon = Icons.check_circle_outline;
        } else {
          accentColor = const Color(0xFF1565C0);
          icon = Icons.auto_awesome;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accentColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accentColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type == 'plan_ready'
                          ? 'Plan Ready'
                          : type == 'morning_briefing'
                              ? 'Good Morning'
                              : 'FitAI Coach',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  // Dismiss button
                  GestureDetector(
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('dashboard_pins')
                          .doc(_uid)
                          .update({'dismissed': true});
                    },
                    child: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              if (type == 'plan_ready' || type == 'weekly_review') ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlanScreen()),
                    );
                  },
                  child: const Text(
                    'View full plan \u2192',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dashboard_pins')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['dismissed'] == true) {
          return const SizedBox.shrink();
        }

        final suggestion =
            data['foodSuggestion'] as Map<String, dynamic>?;
        if (suggestion == null) return const SizedBox.shrink();

        final foodName = suggestion['foodName'] as String? ?? '';
        if (foodName.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E6C9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant_menu,
                      color: Color(0xFF4CAF50), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Suggested for you',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                foodName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 4),
              Text(
                '${(suggestion['portion'] ?? 0)}g \u00b7 '
                '${(suggestion['calories'] ?? 0).toInt()} kcal \u00b7 '
                'P:${(suggestion['protein'] ?? 0).toInt()}g '
                'C:${(suggestion['carbs'] ?? 0).toInt()}g '
                'F:${(suggestion['fats'] ?? 0).toInt()}g',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              if (suggestion['whySuggested'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  suggestion['whySuggested'],
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final dateStr =
                            DateFormat('yyyy-MM-dd').format(now);
                        final hour = now.hour;
                        String mealType = 'Snack';
                        if (hour < 10) {
                          mealType = 'Breakfast';
                        } else if (hour < 14) {
                          mealType = 'Lunch';
                        } else if (hour < 20) {
                          mealType = 'Dinner';
                        }

                        final meal = MealEntry(
                          id: FirebaseFirestore.instance
                              .collection('_')
                              .doc()
                              .id,
                          userId: _uid,
                          date: dateStr,
                          foodName: foodName,
                          quantity:
                              (suggestion['portion'] ?? 100).toDouble(),
                          calories:
                              (suggestion['calories'] ?? 0).toDouble(),
                          protein:
                              (suggestion['protein'] ?? 0).toDouble(),
                          carbs: (suggestion['carbs'] ?? 0).toDouble(),
                          fats: (suggestion['fats'] ?? 0).toDouble(),
                          glycemicIndex:
                              (suggestion['gi'] ?? 0).toInt(),
                          mealType: mealType,
                          inputMethod: 'agent_suggestion',
                          timestamp: now,
                        );
                        await _mealService.addMeal(_uid, meal);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$foodName added!'),
                              backgroundColor: const Color(0xFF4CAF50),
                            ),
                          );
                        }
                      },
                      child: const Text('Add to diary',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      // Dismiss to trigger a new suggestion on next orchestrator run
                      FirebaseFirestore.instance
                          .collection('dashboard_pins')
                          .doc(_uid)
                          .update({'dismissed': true});
                    },
                    child: const Text('Show another',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── MEAL SECTIONS ────────────────────────────────────────

  Widget _buildMealSection(String type, IconData icon, Color color) {
    final meals = _mealsForType(type);
    final totalCal = meals.fold(0.0, (s, m) => s + m.calories);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showMealTypeSheet(type),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, size: 16, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Meal items or empty
          if (meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tap + to add',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            )
          else
            for (int i = 0; i < meals.length; i++) ...[
              _buildMealRow(meals[i]),
              if (i < meals.length - 1)
                Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.shade200),
            ],
          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Text(
              meals.isEmpty ? '' : 'Total: ${totalCal.toInt()} kcal',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow(MealEntry meal) {
    return InkWell(
      onLongPress: () => _deleteMeal(meal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.foodName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meal.calories.toInt()} kcal \u00b7 '
                    'P:${meal.protein.toStringAsFixed(0)}g '
                    'C:${meal.carbs.toStringAsFixed(0)}g '
                    'F:${meal.fats.toStringAsFixed(0)}g',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${meal.calories.toInt()} kcal',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('h:mm a').format(meal.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (_isDiabetes && meal.glycemicIndex > 0) ...[
                  const SizedBox(height: 4),
                  _glycemicBadge(meal.glycemicIndex),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER / CALORIE RING / MACROS / SCORE ───────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieRing() {
    final consumed = _totalCalories;
    final target = _dailyCalorieTarget;
    final remaining = _remaining;
    final consumedValue = consumed.clamp(0.0, target.toDouble());
    final remainingValue = target - consumedValue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 54,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        value: consumedValue > 0 ? consumedValue : 0.001,
                        color: const Color(0xFF4CAF50),
                        radius: 18,
                        showTitle: false,
                      ),
                      if (remainingValue > 0)
                        PieChartSectionData(
                          value: remainingValue,
                          color: const Color(0xFFE0E0E0),
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      consumed.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      '/ ${target.toInt()} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _summaryColumn(
                  'Remaining', '${remaining.toInt()}', Colors.grey.shade600),
              _summaryColumn(
                  'Consumed', '${consumed.toInt()}', const Color(0xFF4CAF50)),
              _summaryColumn('Target', '${target.toInt()}', Colors.black),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          '$label kcal',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildMacroBars() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Macros',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _macroBar('Protein', _totalProtein, _proteinTarget,
              const Color(0xFFEF9A9A)),
          const SizedBox(height: 10),
          _macroBar(
              'Carbs', _totalCarbs, _carbsTarget, const Color(0xFF90CAF9)),
          const SizedBox(height: 10),
          _macroBar('Fat', _totalFats, _fatsTarget, const Color(0xFFFFCC80)),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double value, double target, Color color) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF5F5F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(0)}g',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionalScore() {
    final score = _nutritionalScore;
    Color scoreColor;
    if (score >= 70) {
      scoreColor = const Color(0xFF4CAF50);
    } else if (score >= 40) {
      scoreColor = const Color(0xFFFF9800);
    } else {
      scoreColor = const Color(0xFFF44336);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nutrition Score',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  "Based on today's intake",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                score.toString(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glycemicBadge(int gi) {
    Color color;
    String label;
    if (gi <= 55) {
      color = const Color(0xFF4CAF50);
      label = 'LOW';
    } else if (gi <= 69) {
      color = const Color(0xFFFF9800);
      label = 'MED';
    } else {
      color = const Color(0xFFF44336);
      label = 'HIGH';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET WIDGET ──────────────────────────────────────

class _MealTypeBottomSheet extends StatelessWidget {
  final String mealType;
  final VoidCallback onSearchTap;
  final VoidCallback onPhotoTap;

  const _MealTypeBottomSheet({
    required this.mealType,
    required this.onSearchTap,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Add to $mealType',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how to log your meal',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          // Search Food
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.search, color: Color(0xFF4CAF50)),
            ),
            title: const Text(
              'Search Food',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            subtitle: Text(
              'Find from our food database',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
            onTap: onSearchTap,
          ),
          const Divider(),
          // Take a Photo
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(Icons.camera_alt, color: Color(0xFFFF8F00)),
            ),
            title: const Text(
              'Take a Photo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            subtitle: Text(
              'Coming soon \u2014 Gemini Vision',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
            onTap: onPhotoTap,
          ),
        ],
      ),
    );
  }
}
