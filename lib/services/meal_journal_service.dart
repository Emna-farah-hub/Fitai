import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../agent/core/agent_event.dart';
import '../agent/orchestrator.dart';
import '../models/meal_entry.dart';

class MealJournalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addMeal(String uid, MealEntry meal) async {
    final docRef = _firestore
        .collection('meals')
        .doc(uid)
        .collection('logs')
        .doc(meal.date)
        .collection('entries')
        .doc(meal.id);
    await docRef.set(meal.toMap());

    // Notify agent that a meal was logged
    try {
      AgentOrchestrator().handle(AgentEvent.now(
        type: AgentEventType.mealLogged,
        uid: uid,
        payload: {'meal': meal, 'foodName': meal.foodName},
      ));
    } catch (_) {}
  }

  Future<List<MealEntry>> getRecentMeals(String uid) async {
    try {
      final results = <MealEntry>[];
      final now = DateTime.now();

      for (int i = 0; i < 7; i++) {
        final date = DateFormat('yyyy-MM-dd')
            .format(now.subtract(Duration(days: i)));
        final snapshot = await _firestore
            .collection('meals')
            .doc(uid)
            .collection('logs')
            .doc(date)
            .collection('entries')
            .orderBy('timestamp', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          results.add(MealEntry.fromMap(doc.data()));
        }
        if (results.length >= 10) break;
      }

      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return results.take(10).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteMeal(String uid, String date, String mealId) async {
    await _firestore
        .collection('meals')
        .doc(uid)
        .collection('logs')
        .doc(date)
        .collection('entries')
        .doc(mealId)
        .delete();
  }

  int calculateNutritionalScore({
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFats,
    required double dailyCalorieTarget,
  }) {
    if (totalCalories == 0) return 0;
    int score = 100;

    if (totalCalories > dailyCalorieTarget * 1.1) score -= 20;
    if (totalCalories < dailyCalorieTarget * 0.6) score -= 15;

    final proteinCalories = totalProtein * 4;
    if (totalCalories > 0 && proteinCalories / totalCalories < 0.10) {
      score -= 10;
    }

    final fatCalories = totalFats * 9;
    if (totalCalories > 0 && fatCalories / totalCalories > 0.40) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  Stream<List<MealEntry>> watchTodayMeals(String uid) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _firestore
        .collection('meals')
        .doc(uid)
        .collection('logs')
        .doc(today)
        .collection('entries')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MealEntry.fromMap(doc.data()))
            .toList());
  }
}
