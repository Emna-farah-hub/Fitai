import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Displays the 7-day meal plan from Firestore.
/// Reads from `meal_plan/{uid}` with structure:
///   days: { "1": {date, breakfast, lunch, dinner, snack, dailyTotal}, ... }
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
          'Your 7-Day Plan',
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
    final version = _plan!['version'] ?? 1;
    final reason = _plan!['generationReason'] ?? 'initial';
    final calorieTarget = _plan!['dailyCalorieTarget'] ?? 2000;

    final dayData = days['$_selectedDay'] as Map<String, dynamic>?;

    return Column(
      children: [
        // Plan info header
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFF1F8E9),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF4CAF50), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan v$version \u00b7 $reason \u00b7 ${calorieTarget} kcal/day',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // Day selector — 7 days, not 30
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 7,
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
                    // Day date
                    if (dayData['date'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\u{1F4C5} ${_formatDate(dayData['date'])}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF8F00),
                              fontWeight: FontWeight.w500),
                        ),
                      ),

                    // Meals
                    _buildMealCard('Breakfast', Icons.free_breakfast,
                        const Color(0xFFFF8F00), dayData['breakfast'],
                        dayNumber: _selectedDay, mealType: 'breakfast'),
                    const SizedBox(height: 12),
                    _buildMealCard('Lunch', Icons.lunch_dining,
                        const Color(0xFF2E7D32), dayData['lunch'],
                        dayNumber: _selectedDay, mealType: 'lunch'),
                    const SizedBox(height: 12),
                    _buildMealCard('Dinner', Icons.dinner_dining,
                        const Color(0xFF1565C0), dayData['dinner'],
                        dayNumber: _selectedDay, mealType: 'dinner'),
                    const SizedBox(height: 12),
                    _buildMealCard('Snack', Icons.cookie,
                        const Color(0xFF6A1B9A), dayData['snack'],
                        dayNumber: _selectedDay, mealType: 'snack'),

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

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return DateFormat('EEEE, d MMMM').format(date);
    } catch (_) {
      return iso;
    }
  }

  Widget _buildMealCard(
      String type, IconData icon, Color color, Map<String, dynamic>? meal,
      {required int dayNumber, required String mealType}) {
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

    final isConfirmed = meal['confirmed'] == true;
    final isSwapped = meal['swapped'] == true;

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(type,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const Spacer(),
                if (isConfirmed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '\u2713 Eaten',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32)),
                    ),
                  ),
                if (isSwapped) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Swapped',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Meal name
            Text(
              meal['name']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 4),
            // Macros line
            Text(
              '${(meal['calories'] ?? 0)} kcal \u00b7 '
              'P:${(meal['protein'] ?? 0)}g '
              'C:${(meal['carbs'] ?? 0)}g '
              'F:${(meal['fats'] ?? 0)}g'
              '${meal['glycemicIndex'] != null ? ' \u00b7 GI:${meal['glycemicIndex']}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            // Cuisine + tags
            if (meal['cuisine'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (meal['cuisine'] == 'tunisian')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '\u{1F1F9}\u{1F1F3} Tunisian',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC62828)),
                      ),
                    ),
                ],
              ),
            ],
            // Action buttons (only if not confirmed)
            if (!isConfirmed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _confirmMeal(dayNumber, mealType),
                      child: const Text(
                        'I ate this',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () => _showSwapOptions(dayNumber, mealType),
                    child: const Text('Swap',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmMeal(int dayNumber, String mealType) async {
    // Use orchestrator method (already exists in your code)
    try {
      // Direct Firestore update — simpler than going through orchestrator for UI
      final planDoc = await _db.collection('meal_plan').doc(_uid).get();
      if (!planDoc.exists) return;

      final days = Map<String, dynamic>.from(planDoc.data()?['days'] ?? {});
      final day = Map<String, dynamic>.from(days['$dayNumber'] ?? {});
      final meal = Map<String, dynamic>.from(day[mealType] ?? {});
      if (meal.isEmpty) return;

      meal['confirmed'] = true;
      day[mealType] = meal;
      days['$dayNumber'] = day;

      await _db.collection('meal_plan').doc(_uid).update({'days': days});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u2713 ${meal['name']} marked as eaten'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        _loadPlan(); // Refresh
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to confirm meal')),
        );
      }
    }
  }

  void _showSwapOptions(int dayNumber, String mealType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Swap meal',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon \u2014 alternative meal selection',
              style: TextStyle(color: Colors.grey.shade600),
            ),
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
          _totalStat('Calories', '${total['calories'] ?? 0}',
              const Color(0xFF4CAF50)),
          _totalStat('Protein', '${total['protein'] ?? 0}g',
              const Color(0xFFEF5350)),
          _totalStat('Carbs', '${total['carbs'] ?? 0}g',
              const Color(0xFF42A5F5)),
          _totalStat(
              'Fats', '${total['fats'] ?? 0}g', const Color(0xFFFFA726)),
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