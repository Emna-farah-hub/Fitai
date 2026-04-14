import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/meal_entry.dart';
import '../../../screens/daily_dashboard_screen.dart';
import '../../../screens/chat_screen.dart';
import '../../../screens/food_search_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'tabs/profile_tab.dart';

/// Main dashboard screen with bottom navigation (5 tabs).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    if (authProvider.currentUser != null && !userProvider.hasProfile) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }
  }

  void _onTabTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const FoodSearchScreen(mealType: 'Lunch'),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const DailyDashboardScreen(),
      const SizedBox.shrink(),
      const ChatScreen(),
      const _HistoryTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Log Meal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History Tab — "Food Diary" redesign
// ---------------------------------------------------------------------------

const _historyMealSections = [
  ('Breakfast', Icons.free_breakfast, Color(0xFFFF8F00)),
  ('Lunch', Icons.lunch_dining, Color(0xFF2E7D32)),
  ('Dinner', Icons.dinner_dining, Color(0xFF1565C0)),
  ('Snack', Icons.cookie, Color(0xFF6A1B9A)),
];

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  double _dailyCalorieTarget = 1800;

  // Ordered list of date keys (today first) — includes days with no meals
  List<String> _dateKeys = [];
  Map<String, List<MealEntry>> _grouped = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Load calorie target
    try {
      final userDoc =
          await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final t = (userDoc.data()!['dailyCalorieGoal'] ?? 1800).toDouble();
        _dailyCalorieTarget = t > 0 ? t : 1800;
      }
    } catch (_) {}

    final now = DateTime.now();
    final Map<String, List<MealEntry>> grouped = {};
    final List<String> dateKeys = [];

    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      dateKeys.add(dateKey);

      try {
        final snapshot = await _firestore
            .collection('meals')
            .doc(uid)
            .collection('logs')
            .doc(dateKey)
            .collection('entries')
            .orderBy('timestamp')
            .get();

        if (snapshot.docs.isNotEmpty) {
          grouped[dateKey] = snapshot.docs
              .map((doc) => MealEntry.fromMap(doc.data()))
              .toList();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _dateKeys = dateKeys;
      _grouped = grouped;
      _isLoading = false;
    });
  }

  // ─── STATS ────────────────────────────────────────────────

  int get _daysTracked =>
      _grouped.values.where((list) => list.isNotEmpty).length;

  int get _totalMeals =>
      _grouped.values.fold(0, (s, list) => s + list.length);

  int get _avgCalPerDay {
    if (_daysTracked == 0) return 0;
    final totalCal = _grouped.values
        .expand((list) => list)
        .fold(0.0, (s, m) => s + m.calories);
    return (totalCal / _daysTracked).round();
  }

  bool get _hasAnyMeals => _grouped.values.any((list) => list.isNotEmpty);

  // ─── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Food Diary',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : !_hasAnyMeals
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _buildSummaryCard(),
                      for (int i = 0; i < _dateKeys.length; i++) ...[
                        _buildDateSection(_dateKeys[i]),
                        if (i < _dateKeys.length - 1)
                          Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Colors.grey.shade200),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Your food diary is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start logging meals to see your history',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const FoodSearchScreen(mealType: 'Lunch'),
                  ),
                );
              },
              child: const Text(
                'Log your first meal',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SUMMARY CARD ─────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statColumn(
              'This Week',
              '$_daysTracked days tracked',
              null,
            ),
          ),
          Expanded(
            child: _statColumn(
              'Avg/Day',
              '$_avgCalPerDay kcal',
              const Color(0xFF4CAF50),
            ),
          ),
          Expanded(
            child: _statColumn(
              'Meals Logged',
              '$_totalMeals total',
              Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color? valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ─── DATE SECTION ─────────────────────────────────────────

  Widget _buildDateSection(String dateKey) {
    final date = DateTime.parse(dateKey);
    final meals = _grouped[dateKey] ?? [];
    final dayCal = meals.fold(0.0, (s, m) => s + m.calories);

    Color calColor;
    if (meals.isEmpty) {
      calColor = Colors.grey;
    } else if ((dayCal - _dailyCalorieTarget).abs() <=
        _dailyCalorieTarget * 0.1) {
      calColor = const Color(0xFF4CAF50);
    } else if (dayCal > _dailyCalorieTarget) {
      calColor = const Color(0xFFF44336);
    } else {
      calColor = Colors.grey.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      DateFormat('d MMMM').format(date),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                meals.isEmpty ? '0 kcal' : '${dayCal.toInt()} kcal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: calColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No meals logged',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            )
          else
            for (final section in _historyMealSections)
              _buildHistoryMealSection(section.$1, section.$2, section.$3, meals),
        ],
      ),
    );
  }

  Widget _buildHistoryMealSection(
      String type, IconData icon, Color color, List<MealEntry> allMeals) {
    final meals = allMeals
        .where((m) => m.mealType.toLowerCase() == type.toLowerCase())
        .toList();
    if (meals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Meal rows
          for (int i = 0; i < meals.length; i++) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meals[i].foodName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'P:${meals[i].protein.toStringAsFixed(0)}g '
                          'C:${meals[i].carbs.toStringAsFixed(0)}g '
                          'F:${meals[i].fats.toStringAsFixed(0)}g',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${meals[i].calories.toInt()} kcal',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(meals[i].timestamp),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (i < meals.length - 1)
              Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }
}
