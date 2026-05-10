import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_assets.dart';
import '../core/constants/app_colors.dart';
import '../models/meal_entry.dart';
import '../presentation/widgets/ai_avatar.dart';
import '../presentation/widgets/app_card.dart';
import '../presentation/widgets/illustration_widget.dart';
import '../presentation/widgets/meal_logged_overlay.dart';
import '../presentation/widgets/plant_refresh_indicator.dart';
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
  double _animatedProgress = 0.0;
  bool _isDismissingAgentCard = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  double get _totalCalories =>
      _todayMeals.fold(0.0, (total, meal) => total + meal.calories);
  double get _totalProtein =>
      _todayMeals.fold(0.0, (total, meal) => total + meal.protein);
  double get _totalCarbs =>
      _todayMeals.fold(0.0, (total, meal) => total + meal.carbs);
  double get _totalFats =>
      _todayMeals.fold(0.0, (total, meal) => total + meal.fats);

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
    ('Breakfast', Icons.free_breakfast, AppColors.mealBreakfast),
    ('Lunch', Icons.lunch_dining, AppColors.mealLunch),
    ('Dinner', Icons.dinner_dining, AppColors.mealDinner),
    ('Snack', Icons.cookie, AppColors.mealSnack),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscription = _mealService.watchTodayMeals(_uid).listen((meals) {
      if (mounted) setState(() => _todayMeals = meals);
    });
    MealJournalService.onMealLogged = _handleMealLogged;
  }

  @override
  void dispose() {
    if (MealJournalService.onMealLogged == _handleMealLogged) {
      MealJournalService.onMealLogged = null;
    }
    _subscription?.cancel();
    super.dispose();
  }

  void _handleMealLogged(String foodName, double calories) {
    if (!mounted) return;
    MealLoggedOverlay.show(
      context,
      foodName: foodName,
      calories: calories,
      previousTotal: _totalCalories,
      dailyTarget: _dailyCalorieTarget,
    );
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
          _dailyCalorieTarget = (data['dailyCalorieGoal'] ?? 1800).toDouble();
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
              backgroundColor: AppColors.primary,
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
      HapticFeedback.heavyImpact();
      await _mealService.deleteMeal(_uid, meal.date, meal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: PlantRefreshIndicator(
        onRefresh: _loadProfile,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildNutritionSliverAppBar(),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 80),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAgentCard(),
                  _buildDiscoverMealsCard(),
                  _buildHeader(),
                  _buildNutritionalScore(),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Today's Meals",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final section in _mealSections) ...[
                    _buildMealSection(section.$1, section.$2, section.$3),
                    const SizedBox(height: 12),
                  ],
                  _buildSuggestionSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMealTypeSheet('Lunch'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  SliverAppBar _buildNutritionSliverAppBar() {
    final date = DateFormat('EEE, d MMM').format(DateTime.now());

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.backgroundSoft,
      surfaceTintColor: AppColors.backgroundSoft,
      title: Text(
        '$date • ${_totalCalories.toInt()} kcal',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildFlexibleNutritionContent(),
      ),
    );
  }

  Widget _buildFlexibleNutritionContent() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _buildCalorieRing(compact: true)),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _buildMacroBars(compact: true)),
                ],
              ),
            ),
          ],
        ),
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
            colors: [AppColors.primary, AppColors.primaryLight],
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
        final severity = data['severity'] as String? ?? 'info';
        final type = data['type'] as String? ?? '';
        final timestamp = data['createdAt'] ?? data['timestamp'];

        String badgeLabel;
        Color badgeBackground;
        Color badgeColor;
        if (severity == 'warning') {
          badgeLabel = 'Alert!';
          badgeBackground = AppColors.warningSurface;
          badgeColor = AppColors.warning;
        } else if (severity == 'success') {
          badgeLabel = 'Great job!';
          badgeBackground = AppColors.successSurface;
          badgeColor = AppColors.success;
        } else {
          badgeLabel = 'Tip';
          badgeBackground = AppColors.primarySurface;
          badgeColor = AppColors.primaryDark;
        }

        return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FloatCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AiAvatar(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FitAI Coach',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _relativeTimestamp(timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            if (_isDismissingAgentCard) return;
                            setState(() => _isDismissingAgentCard = true);
                            await Future.delayed(
                              const Duration(milliseconds: 260),
                            );
                            if (!mounted) return;
                            await FirebaseFirestore.instance
                                .collection('dashboard_pins')
                                .doc(_uid)
                                .update({'dismissed': true});
                            if (mounted) {
                              setState(() => _isDismissingAgentCard = false);
                            }
                          },
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    if (type == 'plan_ready' || type == 'weekly_review') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PlanScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'View full plan ->',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0)
            .animate(target: _isDismissingAgentCard ? 1 : 0)
            .slideY(
              begin: 0,
              end: -0.3,
              duration: 250.ms,
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 250.ms, curve: Curves.easeOut);
      },
    );
  }

  String _relativeTimestamp(dynamic timestamp) {
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }

    if (date == null) return 'Just now';

    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }
    return DateFormat('MMM d').format(date);
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

        final suggestion = data['foodSuggestion'] as Map<String, dynamic>?;
        if (suggestion == null) return const SizedBox.shrink();

        final foodName = suggestion['foodName'] as String? ?? '';
        if (foodName.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Suggested for you',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                foodName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
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
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final dateStr = DateFormat('yyyy-MM-dd').format(now);
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
                          quantity: (suggestion['portion'] ?? 100).toDouble(),
                          calories: (suggestion['calories'] ?? 0).toDouble(),
                          protein: (suggestion['protein'] ?? 0).toDouble(),
                          carbs: (suggestion['carbs'] ?? 0).toDouble(),
                          fats: (suggestion['fats'] ?? 0).toDouble(),
                          glycemicIndex: (suggestion['gi'] ?? 0).toInt(),
                          mealType: mealType,
                          inputMethod: 'agent_suggestion',
                          timestamp: now,
                        );
                        await _mealService.addMeal(_uid, meal);
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$foodName added!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: const Text(
                        'Add to diary',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      // Dismiss to trigger a new suggestion on next orchestrator run
                      FirebaseFirestore.instance
                          .collection('dashboard_pins')
                          .doc(_uid)
                          .update({'dismissed': true});
                    },
                    child: const Text(
                      'Show another',
                      style: TextStyle(fontSize: 13),
                    ),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceFloat,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 3,
            child: DecoratedBox(decoration: BoxDecoration(color: color)),
          ),
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  color: color.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, size: 16, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                // Meal items or empty
                if (meals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const IllustrationWidget(
                          assetPath: AppAssets.emptyMealsIllustration,
                          fallbackIcon: Icons.restaurant_outlined,
                          height: 80,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nothing logged yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showMealTypeSheet(type),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              '+ Add $type',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (int i = 0; i < meals.length; i++) ...[
                    _buildMealRow(meals[i]),
                    if (i < meals.length - 1)
                      Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Colors.grey.shade200,
                      ),
                  ],
                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
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
                    color: AppColors.primary,
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

  Widget _buildCalorieRing({bool compact = false}) {
    final consumed = _totalCalories;
    final target = _dailyCalorieTarget;
    final remaining = _remaining;
    final targetProgress = target > 0 ? consumed / target : 0.0;

    return CalorieRingCompletion(
      consumed: consumed,
      target: target,
      remaining: remaining,
      beginProgress: _animatedProgress,
      targetProgress: targetProgress,
      compact: compact,
      dateKey: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      onProgressSettled: (progress) => _animatedProgress = progress,
      summaryBuilder: _summaryColumn,
    );
  }

  Widget _summaryColumn(
    String label,
    String value,
    Color valueColor, {
    bool compact = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 12 : 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          '$label kcal',
          style: TextStyle(
            fontSize: compact ? 9 : 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBars({bool compact = false}) {
    final content = FloatCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macros',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          _macroBar(
            'Protein',
            _totalProtein,
            _proteinTarget,
            const Color(0xFFEF9A9A),
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 10),
          _macroBar(
            'Carbs',
            _totalCarbs,
            _carbsTarget,
            const Color(0xFF90CAF9),
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 10),
          _macroBar(
            'Fat',
            _totalFats,
            _fatsTarget,
            const Color(0xFFFFCC80),
            compact: compact,
          ),
        ],
      ),
    );

    if (compact) return content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: content,
    );
  }

  Widget _macroBar(
    String label,
    double value,
    double target,
    Color color, {
    bool compact = false,
  }) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: compact ? 44 : 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF5F5F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: compact ? 6 : 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: compact ? 34 : 48,
          child: Text(
            '${value.toStringAsFixed(0)}g',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionalScore() {
    final score = _nutritionalScore;
    Color scoreColor;
    if (score >= 70) {
      scoreColor = AppColors.primary;
    } else if (score >= 40) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FloatCard(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _glycemicBadge(int gi) {
    Color color;
    String label;
    if (gi <= 55) {
      color = AppColors.primary;
      label = 'LOW';
    } else if (gi <= 69) {
      color = AppColors.warning;
      label = 'MED';
    } else {
      color = AppColors.error;
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

typedef CalorieSummaryBuilder =
    Widget Function(
      String label,
      String value,
      Color valueColor, {
      bool compact,
    });

class CalorieRingCompletion extends StatefulWidget {
  final double consumed;
  final double target;
  final double remaining;
  final double beginProgress;
  final double targetProgress;
  final bool compact;
  final String dateKey;
  final ValueChanged<double> onProgressSettled;
  final CalorieSummaryBuilder summaryBuilder;

  const CalorieRingCompletion({
    super.key,
    required this.consumed,
    required this.target,
    required this.remaining,
    required this.beginProgress,
    required this.targetProgress,
    required this.compact,
    required this.dateKey,
    required this.onProgressSettled,
    required this.summaryBuilder,
  });

  @override
  State<CalorieRingCompletion> createState() => _CalorieRingCompletionState();
}

class _CalorieRingCompletionState extends State<CalorieRingCompletion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _completionController;
  late final Animation<double> _ringPulse;
  late final Animation<double> _centerScale;
  Timer? _midnightResetTimer;

  bool _hasShownCompletion = false;
  bool _showCompletionBurst = false;
  late double _previousProgress;

  @override
  void initState() {
    super.initState();
    _previousProgress = widget.beginProgress;
    _completionController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _showCompletionBurst = false);
          }
        });

    _ringPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 4.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 100,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 4.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 100,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 500),
    ]).animate(_completionController);

    _centerScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 150,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 150,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 400),
    ]).animate(_completionController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForCompletion(widget.targetProgress);
    });
    _scheduleMidnightReset();
  }

  @override
  void didUpdateWidget(covariant CalorieRingCompletion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dateKey != oldWidget.dateKey) {
      _hasShownCompletion = false;
      _showCompletionBurst = false;
      _previousProgress = 0.0;
      _completionController.reset();
      _scheduleMidnightReset();
    }
    _checkForCompletion(widget.targetProgress);
    _previousProgress = widget.targetProgress;
  }

  @override
  void dispose() {
    _midnightResetTimer?.cancel();
    _completionController.dispose();
    super.dispose();
  }

  void _scheduleMidnightReset() {
    _midnightResetTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnightResetTimer = Timer(tomorrow.difference(now), () {
      if (!mounted) return;
      setState(() {
        _hasShownCompletion = false;
        _showCompletionBurst = false;
        _previousProgress = 0.0;
      });
      _completionController.reset();
      _scheduleMidnightReset();
    });
  }

  void _checkForCompletion(double progress) {
    if (_hasShownCompletion || _previousProgress >= 1.0 || progress < 1.0) {
      return;
    }
    _hasShownCompletion = true;
    if (!mounted) return;
    setState(() => _showCompletionBurst = true);
    _completionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: widget.beginProgress,
        end: widget.targetProgress,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      onEnd: () => widget.onProgressSettled(widget.targetProgress),
      builder: (context, progress, _) {
        final chartProgress = progress.clamp(0.0, 1.0);
        final consumedValue = widget.target * chartProgress;
        final remainingValue = (widget.target - consumedValue).clamp(
          0.0,
          widget.target,
        );
        final ringSize = widget.compact ? 104.0 : 180.0;
        final centerSpaceRadius = widget.compact ? 30.0 : 54.0;
        final baseRingRadius = widget.compact ? 12.0 : 18.0;
        final progressColor = widget.targetProgress > 1.1
            ? AppColors.warning
            : AppColors.primary;
        final statusLabel = widget.targetProgress > 1.1
            ? 'Over goal'
            : '✓ Goal reached!';
        final showStatusLabel =
            _hasShownCompletion || widget.targetProgress > 1.1;

        return Container(
          margin: widget.compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(widget.compact ? 12 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.compact ? 14 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: widget.compact
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _completionController,
                builder: (context, _) {
                  final ringRadius = baseRingRadius + _ringPulse.value;
                  return SizedBox(
                    height: ringSize,
                    width: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_showCompletionBurst)
                          Positioned.fill(
                            child: IgnorePointer(
                              child:
                                  Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: progressColor.withValues(
                                              alpha: 0.5,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .scaleXY(
                                        begin: 0.8,
                                        end: 1.2,
                                        duration: 400.ms,
                                        curve: Curves.easeOut,
                                      )
                                      .fadeOut(
                                        duration: 400.ms,
                                        curve: Curves.easeOut,
                                      ),
                            ),
                          ),
                        PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: centerSpaceRadius,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                value: consumedValue > 0
                                    ? consumedValue
                                    : 0.001,
                                color: progressColor,
                                radius: ringRadius,
                                showTitle: false,
                              ),
                              if (remainingValue > 0)
                                PieChartSectionData(
                                  value: remainingValue,
                                  color: const Color(0xFFE0E0E0),
                                  radius: ringRadius,
                                  showTitle: false,
                                ),
                            ],
                          ),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                        ),
                        Transform.scale(
                          scale: _centerScale.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.consumed.toInt().toString(),
                                style: TextStyle(
                                  fontSize: widget.compact ? 24 : 32,
                                  fontWeight: FontWeight.bold,
                                  color: progressColor,
                                ),
                              ),
                              Text(
                                '/ ${widget.target.toInt()} kcal',
                                style: TextStyle(
                                  fontSize: widget.compact ? 10 : 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (showStatusLabel) ...[
                SizedBox(height: widget.compact ? 4 : 8),
                Text(
                      statusLabel,
                      style: GoogleFonts.nunito(
                        fontSize: widget.compact ? 11 : 13,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 240.ms)
                    .moveY(begin: 8, end: 0, duration: 240.ms),
              ],
              SizedBox(height: widget.compact ? 8 : 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  widget.summaryBuilder(
                    'Remaining',
                    '${widget.remaining.toInt()}',
                    Colors.grey.shade600,
                    compact: widget.compact,
                  ),
                  widget.summaryBuilder(
                    'Consumed',
                    '${widget.consumed.toInt()}',
                    progressColor,
                    compact: widget.compact,
                  ),
                  widget.summaryBuilder(
                    'Target',
                    '${widget.target.toInt()}',
                    Colors.black,
                    compact: widget.compact,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

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
              backgroundColor: AppColors.primarySurface,
              child: Icon(Icons.search, color: AppColors.primary),
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
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
            onTap: onSearchTap,
          ),
          const Divider(),
          // Take a Photo
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(Icons.camera_alt, color: AppColors.mealBreakfast),
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
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
            onTap: onPhotoTap,
          ),
        ],
      ),
    );
  }
}
