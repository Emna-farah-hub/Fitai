import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Displays the 30-day meal plan from Firestore.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic>? _plan;
  bool _isLoading = true;
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final doc = await _db.collection('meal_plan').doc(_uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _plan = doc.data();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your 30-Day Plan',
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
          : _plan == null
              ? _buildNoPlan()
              : _buildPlanView(),
    );
  }

  Widget _buildNoPlan() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No plan generated yet',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete the agent onboarding to get your plan',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanView() {
    final days = _plan!['days'] as Map<String, dynamic>? ?? {};
    final weeklyThemes =
        _plan!['weeklyThemes'] as Map<String, dynamic>? ?? {};
    final version = _plan!['version'] ?? 1;

    final dayData = days['$_selectedDay'] as Map<String, dynamic>?;

    return Column(
      children: [
        // Plan info header
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFF1F8E9),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan v$version \u00b7 ${_currentWeekTheme(weeklyThemes)}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // Day selector
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 30,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = day == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  width: 52,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Day',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Day content
        Expanded(
          child: dayData == null
              ? const Center(
                  child: Text('No data for this day',
                      style: TextStyle(color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Day theme
                    if (dayData['theme'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\u{2728} ${dayData['theme']}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF8F00),
                              fontWeight: FontWeight.w500),
                        ),
                      ),

                    // Meals
                    _buildMealCard('Breakfast', Icons.free_breakfast,
                        const Color(0xFFFF8F00), dayData['breakfast']),
                    const SizedBox(height: 12),
                    _buildMealCard('Lunch', Icons.lunch_dining,
                        const Color(0xFF2E7D32), dayData['lunch']),
                    const SizedBox(height: 12),
                    _buildMealCard('Dinner', Icons.dinner_dining,
                        const Color(0xFF1565C0), dayData['dinner']),
                    const SizedBox(height: 12),
                    _buildMealCard('Snack', Icons.cookie,
                        const Color(0xFF6A1B9A), dayData['snack']),

                    // Daily totals
                    if (dayData['dailyTotal'] != null) ...[
                      const SizedBox(height: 16),
                      _buildDailyTotalCard(
                          dayData['dailyTotal'] as Map<String, dynamic>),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
        ),
      ],
    );
  }

  String _currentWeekTheme(Map<String, dynamic> themes) {
    final weekNum = ((_selectedDay - 1) ~/ 7) + 1;
    return themes['week$weekNum'] as String? ?? 'Week $weekNum';
  }

  Widget _buildMealCard(
      String type, IconData icon, Color color, Map<String, dynamic>? meal) {
    if (meal == null) {
      return Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(type),
          subtitle: const Text('Not planned',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(type,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            // Food name
            Text(
              meal['suggestion'] ?? '',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 4),
            // Macros
            Text(
              '${(meal['portion'] ?? 0)}g \u00b7 '
              '${(meal['calories'] ?? 0)} kcal \u00b7 '
              'P:${(meal['protein'] ?? 0)}g '
              'C:${(meal['carbs'] ?? 0)}g '
              'F:${(meal['fats'] ?? 0)}g',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            // Recipe tip
            if (meal['recipe'] != null && meal['recipe'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '\u{1F373} ${meal['recipe']}',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700),
              ),
            ],
            // Tunisian alternative
            if (meal['tunisianAlternative'] != null &&
                meal['tunisianAlternative'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '\u{1F1F9}\u{1F1F3} Alternative: ${meal['tunisianAlternative']}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF4CAF50)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTotalCard(Map<String, dynamic> total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _totalStat('Calories', '${total['calories'] ?? 0}', const Color(0xFF4CAF50)),
          _totalStat('Protein', '${total['protein'] ?? 0}g', const Color(0xFFEF5350)),
          _totalStat('Carbs', '${total['carbs'] ?? 0}g', const Color(0xFF42A5F5)),
          _totalStat('Fats', '${total['fats'] ?? 0}g', const Color(0xFFFFA726)),
        ],
      ),
    );
  }

  Widget _totalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
