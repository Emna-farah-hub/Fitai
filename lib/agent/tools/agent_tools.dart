import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import '../../services/meal_catalog_service.dart';

/// Pure data-access tools used by agents. No Gemini calls here.
class AgentTools {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MealCatalogService _mealCatalog = MealCatalogService();

  // ─── READ TOOLS ─────────────────────────────────────────

  /// Tool 1: Wraps a food classification result into structured data
  /// and looks up nutrition from the local food DB.
  Future<Map<String, dynamic>> classifyFoodResult(
    String detectedLabel,
    double confidence,
  ) async {
    try {
      final food = await searchFoodDb(detectedLabel);
      return {
        'detectedLabel': detectedLabel,
        'confidence': confidence,
        'reliable': confidence >= 0.7,
        'nutrition': food,
      };
    } catch (_) {
      return {
        'detectedLabel': detectedLabel,
        'confidence': confidence,
        'reliable': false,
        'nutrition': {'found': false},
      };
    }
  }

  /// Tool 2: Reads today's meal log for a user.
  Future<Map<String, dynamic>> analyzeDailyLog(String uid) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final snapshot = await _db
          .collection('meals')
          .doc(uid)
          .collection('logs')
          .doc(today)
          .collection('entries')
          .orderBy('timestamp')
          .get();

      final meals = snapshot.docs
          .map((d) => MealEntry.fromMap(d.data()))
          .toList();

      double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;
      double totalGI = 0;
      String? lastMealTime;
      final mealList = <Map<String, dynamic>>[];

      for (final m in meals) {
        totalCal += m.calories;
        totalP += m.protein;
        totalC += m.carbs;
        totalF += m.fats;
        totalGI += m.glycemicIndex;
        lastMealTime = m.timestamp.toIso8601String();
        mealList.add({
          'foodName': m.foodName,
          'calories': m.calories,
          'protein': m.protein,
          'carbs': m.carbs,
          'fats': m.fats,
          'mealType': m.mealType,
          'glycemicIndex': m.glycemicIndex,
          'time': DateFormat('h:mm a').format(m.timestamp),
        });
      }

      return {
        'date': today,
        'totalCalories': totalCal,
        'totalProtein': totalP,
        'totalCarbs': totalC,
        'totalFats': totalF,
        'mealCount': meals.length,
        'glycemicScore': meals.isNotEmpty ? totalGI / meals.length : 0,
        'lastMealTime': lastMealTime,
        'meals': mealList,
      };
    } catch (_) {
      return {
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'mealCount': 0,
      };
    }
  }

  /// Tool 3: Reads the full user profile including agentProfile.
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return {'found': false};
      final data = doc.data()!;
      return {
        'found': true,
        'name': data['name'] ?? '',
        'age': data['age'] ?? 0,
        'height': data['height'] ?? 170,
        'weight': data['weight'] ?? 70,
        'sex': data['sex'] ?? 'male',
        'activityLevel': data['activityLevel'] ?? 'Sedentary',
        'fitnessLevel': data['fitnessLevel'] ?? 'Just starting out',
        'conditions': List<String>.from(data['conditions'] ?? []),
        'goals': List<String>.from(data['goals'] ?? []),
        'dietaryPreference': data['dietaryPreference'] ?? 'Classic',
        'bmr': (data['bmr'] ?? 0).toDouble(),
        'tdee': (data['tdee'] ?? 0).toDouble(),
        'dailyCalorieGoal': data['dailyCalorieGoal'] ?? 2000,
        'agentProfile': data['agentProfile'] as Map<String, dynamic>? ?? {},
      };
    } catch (_) {
      return {'found': false};
    }
  }

  /// Tool 4: Searches local food DB by name.
  Future<Map<String, dynamic>> searchFoodDb(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return {'found': false, 'query': query};

    try {
      await _mealCatalog.initialize();
      final mealMatch = _findBestCatalogMealMatch(
        _mealCatalog.getAllMealMaps(),
        q,
      );
      if (mealMatch != null) {
        return _mealCatalogResult(mealMatch);
      }

      // TODO: remove after migration once search_food_db is fully validated
      // against the production meal catalog for all assistant workflows.
      for (final collection in ['tunisian_foods', 'common_foods']) {
        final snap = await _db.collection(collection).get();
        for (final doc in snap.docs) {
          final item = FoodItem.fromMap(doc.data());
          if (item.name.toLowerCase().contains(q)) {
            return {'found': true, ...item.toMap()};
          }
        }
      }
      return {'found': false, 'query': query};
    } catch (_) {
      try {
        for (final collection in ['tunisian_foods', 'common_foods']) {
          final snap = await _db.collection(collection).get();
          for (final doc in snap.docs) {
            final item = FoodItem.fromMap(doc.data());
            if (item.name.toLowerCase().contains(q)) {
              return {'found': true, ...item.toMap()};
            }
          }
        }
      } catch (_) {}

      return {'found': false, 'query': query};
    }
  }

  Map<String, dynamic>? _findBestCatalogMealMatch(
    List<Map<String, dynamic>> meals,
    String query,
  ) {
    Map<String, dynamic>? bestMeal;
    double bestScore = 0.0;

    for (final meal in meals) {
      final name = meal['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final score = _catalogMatchScore(name, query);
      if (score > bestScore) {
        bestScore = score;
        bestMeal = meal;
      }
    }

    if (bestScore < 0.72) return null;
    return bestMeal;
  }

  Map<String, dynamic> _mealCatalogResult(Map<String, dynamic> meal) {
    final tags = <String>[
      ...List<String>.from(meal['tags'] ?? const []),
      ...List<String>.from(meal['dietTags'] ?? const []),
    ];

    return {
      'found': true,
      'id': meal['id']?.toString() ?? '',
      'name': meal['name']?.toString() ?? '',
      'foodName': meal['name']?.toString() ?? '',
      'description': meal['description']?.toString() ?? '',
      'calories': (meal['calories'] as num?)?.toDouble() ?? 0.0,
      'caloriesPer100g': (meal['calories'] as num?)?.toDouble() ?? 0.0,
      'protein': (meal['protein'] as num?)?.toDouble() ?? 0.0,
      'carbs': (meal['carbs'] as num?)?.toDouble() ?? 0.0,
      'fats': (meal['fats'] as num?)?.toDouble() ?? 0.0,
      'glycemicIndex': (meal['glycemicIndex'] as num?)?.toInt() ?? 0,
      'gi': (meal['glycemicIndex'] as num?)?.toInt() ?? 0,
      'isTunisian': meal['cuisine']?.toString() == 'tunisian',
      'source': 'meal_catalog',
      'category': meal['mealType']?.toString() ?? '',
      'mealType': meal['mealType']?.toString() ?? '',
      'cuisine': meal['cuisine']?.toString() ?? 'international',
      'tags': tags,
      'dietTags': List<String>.from(meal['dietTags'] ?? const []),
      'suitableFor': List<String>.from(meal['suitableFor'] ?? const []),
      'ingredients': (meal['ingredients'] as List? ?? const [])
          .map((entry) {
            if (entry is Map) return entry['name']?.toString() ?? '';
            return entry?.toString() ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toList(),
      'servings': (meal['servings'] as num?)?.toInt() ?? 1,
      'portionBasis': '1 serving',
    };
  }

  double _catalogMatchScore(String candidate, String query) {
    final normalizedCandidate = _normalizeSearchText(candidate);
    final normalizedQuery = _normalizeSearchText(query);

    if (normalizedCandidate.isEmpty || normalizedQuery.isEmpty) return 0.0;
    if (normalizedCandidate == normalizedQuery) return 1.0;

    final queryTokens = _searchTokens(normalizedQuery);
    final candidateTokens = _searchTokens(normalizedCandidate);
    if (queryTokens.isEmpty || candidateTokens.isEmpty) return 0.0;

    if (queryTokens.length == 1) {
      return 0.0;
    }

    if (normalizedCandidate.contains(normalizedQuery)) {
      return 0.9;
    }

    final overlap = queryTokens.intersection(candidateTokens).length;
    final tokenCoverage = overlap / queryTokens.length;
    final candidateCoverage = overlap / candidateTokens.length;
    return (tokenCoverage * 0.8) + (candidateCoverage * 0.2);
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _searchTokens(String value) {
    return value
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length > 2)
        .toSet();
  }

  /// Tool 5: Gets weekly history (last 7 days).
  Future<Map<String, dynamic>> getWeeklyHistory(String uid) async {
    try {
      final now = DateTime.now();
      final days = <Map<String, dynamic>>[];
      double totalCal = 0;
      int daysLogged = 0;
      final mealTypeCounts = <String, int>{};

      for (int i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(day);
        final snap = await _db
            .collection('meals')
            .doc(uid)
            .collection('logs')
            .doc(dateKey)
            .collection('entries')
            .get();

        double dayCal = 0, dayP = 0, dayC = 0, dayF = 0;
        double dayGI = 0;
        int count = 0;

        for (final doc in snap.docs) {
          final m = MealEntry.fromMap(doc.data());
          dayCal += m.calories;
          dayP += m.protein;
          dayC += m.carbs;
          dayF += m.fats;
          dayGI += m.glycemicIndex;
          count++;
          mealTypeCounts[m.mealType.toLowerCase()] =
              (mealTypeCounts[m.mealType.toLowerCase()] ?? 0) + 1;
        }

        if (count > 0) {
          daysLogged++;
          totalCal += dayCal;
        }

        days.add({
          'date': dateKey,
          'calories': dayCal,
          'protein': dayP,
          'carbs': dayC,
          'fats': dayF,
          'mealCount': count,
          'glycemicScore': count > 0 ? dayGI / count : 0,
        });
      }

      // Find most skipped meal type
      final allTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
      String mostSkipped = 'breakfast';
      int minCount = 999;
      for (final t in allTypes) {
        final c = mealTypeCounts[t] ?? 0;
        if (c < minCount) {
          minCount = c;
          mostSkipped = t;
        }
      }

      return {
        'days': days,
        'daysLogged': daysLogged,
        'averageDailyCalories': daysLogged > 0 ? totalCal / daysLogged : 0,
        'mostSkippedMealType': mostSkipped,
        'consistencyScore': ((daysLogged / 7) * 100).round(),
        'mealTypeCounts': mealTypeCounts,
      };
    } catch (_) {
      return {'days': [], 'daysLogged': 0, 'consistencyScore': 0};
    }
  }

  // ─── WRITE TOOLS ────────────────────────────────────────

  /// Pins a message to the user's dashboard.
  Future<void> pinToDashboard(String uid, Map<String, dynamic> pinData) async {
    await _db.collection('dashboard_pins').doc(uid).set({
      ...pinData,
      'createdAt': FieldValue.serverTimestamp(),
      'dismissed': false,
    });
  }

  /// Updates the user's daily calorie target.
  Future<void> updateCalorieTarget(
    String uid,
    int newTarget,
    String reason,
  ) async {
    await _db.collection('users').doc(uid).update({
      'dailyCalorieGoal': newTarget,
    });
    await logAgentAction(uid, {
      'type': 'calorie_target_updated',
      'newTarget': newTarget,
      'reason': reason,
    });
  }

  /// Saves a full meal plan.
  Future<void> saveMealPlan(String uid, Map<String, dynamic> planData) async {
    await _db.collection('meal_plan').doc(uid).set(planData);
  }

  /// Logs an agent action for auditing.
  Future<void> logAgentAction(
    String uid,
    Map<String, dynamic> actionData,
  ) async {
    await _db.collection('agent_actions').doc(uid).collection('log').add({
      ...actionData,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
