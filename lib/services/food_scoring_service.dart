import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/swipe_meal.dart';

enum NutritionGoalType { weightLoss, muscleGain, diabetes, balanced }

class GoalProfile {
  final NutritionGoalType primaryGoal;
  final List<String> goals;
  final List<String> conditions;

  const GoalProfile({
    required this.primaryGoal,
    required this.goals,
    required this.conditions,
  });

  bool get isWeightLoss => primaryGoal == NutritionGoalType.weightLoss;
  bool get isMuscleGain => primaryGoal == NutritionGoalType.muscleGain;
  bool get isDiabetes => primaryGoal == NutritionGoalType.diabetes;

  String get label {
    switch (primaryGoal) {
      case NutritionGoalType.weightLoss:
        return 'weight loss';
      case NutritionGoalType.muscleGain:
        return 'muscle gain';
      case NutritionGoalType.diabetes:
        return 'diabetes';
      case NutritionGoalType.balanced:
        return 'balanced nutrition';
    }
  }
}

class RankedMeal<T> {
  final T meal;
  final double goalCompatibilityScore;
  final double preferenceScore;
  final double finalScore;

  const RankedMeal({
    required this.meal,
    required this.goalCompatibilityScore,
    required this.preferenceScore,
    required this.finalScore,
  });
}

class FoodScoringService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const double _swipeWeight = 1.0;
  static const double _mealTypeWeight = 0.5;
  static const double _cuisineWeight = 0.8;
  static const double _weeklyPositiveWeight = 0.7;
  static const double _weeklyNegativeWeight = -0.45;
  static const double _weeklySwipeReinforcement = 0.2;
  static const double _decayFactor = 0.9;
  static const int _decayAfterDays = 7;
  static const int _maxSwipeHistory = 200;
  static const double _maxScore = 15.0;

  GoalProfile deriveGoalProfile({
    required List<String> goals,
    required List<String> conditions,
  }) {
    final normalizedGoals = goals.map(_normalizeKey).toList();
    final normalizedConditions = conditions.map(_normalizeKey).toList();

    final hasDiabetes = normalizedGoals.any((g) => g.contains('glycemic')) ||
        normalizedGoals.any((g) => g.contains('diabet')) ||
        normalizedConditions.any((c) => c.contains('diabet'));
    if (hasDiabetes) {
      return GoalProfile(
        primaryGoal: NutritionGoalType.diabetes,
        goals: goals,
        conditions: conditions,
      );
    }

    final hasWeightLoss =
        normalizedGoals.any((g) => g.contains('lose') || g.contains('weight'));
    if (hasWeightLoss) {
      return GoalProfile(
        primaryGoal: NutritionGoalType.weightLoss,
        goals: goals,
        conditions: conditions,
      );
    }

    final hasMuscleGain =
        normalizedGoals.any((g) => g.contains('muscle') || g.contains('gain'));
    if (hasMuscleGain) {
      return GoalProfile(
        primaryGoal: NutritionGoalType.muscleGain,
        goals: goals,
        conditions: conditions,
      );
    }

    return GoalProfile(
      primaryGoal: NutritionGoalType.balanced,
      goals: goals,
      conditions: conditions,
    );
  }

  bool isGoalSafeMealMap(
    Map<String, dynamic> meal,
    GoalProfile goalProfile,
  ) {
    return _isGoalSafe(_featuresFromMealMap(meal), goalProfile);
  }

  bool isGoalSafeSwipeMeal(
    SwipeMeal meal,
    GoalProfile goalProfile,
  ) {
    return _isGoalSafe(_featuresFromSwipeMeal(meal), goalProfile);
  }

  Future<List<RankedMeal<Map<String, dynamic>>>> rankMealMaps({
    required String uid,
    required List<Map<String, dynamic>> meals,
    required List<String> goals,
    required List<String> conditions,
  }) async {
    final goalProfile =
        deriveGoalProfile(goals: goals, conditions: conditions);
    final preferenceState = await _loadPreferenceState(uid);

    final ranked = <RankedMeal<Map<String, dynamic>>>[];
    for (final meal in meals) {
      final features = _featuresFromMealMap(meal);
      if (!_isGoalSafe(features, goalProfile)) continue;

      final goalScore = _goalCompatibilityScore(features, goalProfile);
      final preferenceScore =
          _preferenceScore(features, preferenceState);
      ranked.add(RankedMeal(
        meal: Map<String, dynamic>.from(meal),
        goalCompatibilityScore: goalScore,
        preferenceScore: preferenceScore,
        finalScore: computeFinalScore(
          goalCompatibilityScore: goalScore,
          preferenceScore: preferenceScore,
        ),
      ));
    }

    ranked.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return ranked;
  }

  Future<List<RankedMeal<SwipeMeal>>> rankSwipeMeals({
    required String uid,
    required List<SwipeMeal> meals,
    required List<String> goals,
    required List<String> conditions,
  }) async {
    final goalProfile =
        deriveGoalProfile(goals: goals, conditions: conditions);
    final preferenceState = await _loadPreferenceState(uid);

    final ranked = <RankedMeal<SwipeMeal>>[];
    for (final meal in meals) {
      final features = _featuresFromSwipeMeal(meal);
      if (!_isGoalSafe(features, goalProfile)) continue;

      final goalScore = _goalCompatibilityScore(features, goalProfile);
      final preferenceScore =
          _preferenceScore(features, preferenceState);
      ranked.add(RankedMeal(
        meal: meal,
        goalCompatibilityScore: goalScore,
        preferenceScore: preferenceScore,
        finalScore: computeFinalScore(
          goalCompatibilityScore: goalScore,
          preferenceScore: preferenceScore,
        ),
      ));
    }

    ranked.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return ranked;
  }

  double computeFinalScore({
    required double goalCompatibilityScore,
    required double preferenceScore,
  }) {
    return (goalCompatibilityScore * 0.6) + (preferenceScore * 0.4);
  }

  Future<void> recordSwipe({
    required String uid,
    required FoodItem food,
    required bool liked,
  }) async {
    await _recordPreferenceFeedback(
      uid: uid,
      mealFeatures: _MealFeatures(
        id: food.id,
        name: food.name,
        calories: food.caloriesPer100g,
        protein: food.protein,
        carbs: food.carbs,
        fats: food.fats,
        glycemicIndex: food.glycemicIndex,
        mealType: food.category.isEmpty ? 'Snack' : food.category,
        cuisine: food.isTunisian ? 'tunisian' : food.source,
        tags: food.tags,
        ingredients: [food.name],
        suitableFor: const [],
      ),
      liked: liked,
      likedId: food.id,
    );
  }

  Future<void> recordMealSwipe({
    required String uid,
    required SwipeMeal meal,
    required bool liked,
  }) async {
    await _recordPreferenceFeedback(
      uid: uid,
      mealFeatures: _featuresFromSwipeMeal(meal),
      liked: liked,
      likedId: meal.id,
    );
  }

  Future<void> applyWeeklyLearning({
    required String uid,
    required List<Map<String, dynamic>> eatenMeals,
    required List<Map<String, dynamic>> skippedMeals,
    required List<Map<String, dynamic>> swipeHistory,
    required int recommendedMeals,
    required int eatenRecommendations,
    required int skippedRecommendations,
  }) async {
    final docRef = _db.collection('preferences').doc(uid);
    final doc = await docRef.get();
    final data = doc.exists ? doc.data()! : _emptyPreferences();
    final mutated = _copyPreferenceDocument(data);

    for (final meal in eatenMeals) {
      _applyMealToPreferenceMaps(
        mutated,
        _featuresFromMealMap(meal),
        _weeklyPositiveWeight,
      );
    }

    for (final meal in skippedMeals) {
      _applyMealToPreferenceMaps(
        mutated,
        _featuresFromMealMap(meal),
        _weeklyNegativeWeight,
      );
    }

    for (final swipe in swipeHistory) {
      final liked = swipe['liked'] == true;
      final delta = liked
          ? _weeklySwipeReinforcement
          : -_weeklySwipeReinforcement;
      _applySerializedFeedback(mutated, swipe, delta);
    }

    _refreshIngredientLists(mutated);
    mutated['lastUpdated'] = Timestamp.now();
    mutated['userPreferences']['weeklyLearning'] = {
      'updatedAt': Timestamp.now(),
      'recommendedMeals': recommendedMeals,
      'eatenRecommendations': eatenRecommendations,
      'skippedRecommendations': skippedRecommendations,
      'eatenCount': eatenMeals.length,
      'skippedCount': skippedMeals.length,
      'swipeEvents': swipeHistory.length,
    };

    await docRef.set(mutated, SetOptions(merge: true));
  }

  Future<double> getScoreForFood({
    required String uid,
    required FoodItem food,
  }) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) return 0.0;
    return _calculateFoodScore(food, scores);
  }

  Future<List<ScoredFood>> rankFoods({
    required String uid,
    required List<FoodItem> foods,
  }) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) {
      return foods.map((f) => ScoredFood(food: f, score: 0.0)).toList();
    }

    final scored = foods.map((food) {
      final score = _calculateFoodScore(food, scores);
      return ScoredFood(food: food, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  Future<List<String>> getLikedFoodIds(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['likedFoodIds'] ?? []);
  }

  Future<List<String>> getDislikedFoodIds(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['dislikedFoodIds'] ?? []);
  }

  Future<int> getTotalSwipes(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return 0;
    return (doc.data()?['totalSwipes'] ?? 0) as int;
  }

  Future<Map<String, double>> getTagScores(String uid) async {
    return _getTagScores(uid);
  }

  Future<List<MapEntry<String, double>>> getTopTags(
    String uid, {
    int limit = 10,
  }) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) return [];

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  Future<List<MapEntry<String, double>>> getBottomTags(
    String uid, {
    int limit = 10,
  }) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) return [];

    final sorted = scores.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.take(limit).toList();
  }

  Future<bool> hasBeenSwiped({
    required String uid,
    required String foodId,
  }) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return false;
    final liked = List<String>.from(doc.data()?['likedFoodIds'] ?? []);
    final disliked = List<String>.from(doc.data()?['dislikedFoodIds'] ?? []);
    return liked.contains(foodId) || disliked.contains(foodId);
  }

  Future<Map<String, dynamic>> getPreferenceSummary(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) {
      return {
        'hasPreferences': false,
        'totalSwipes': 0,
        'topTags': <String>[],
        'dislikedTags': <String>[],
        'likedFoodCount': 0,
        'dislikedFoodCount': 0,
        'userPreferences': _emptyUserPreferences(),
      };
    }

    final data = _copyPreferenceDocument(doc.data()!);
    _refreshIngredientLists(data);

    final tagScores = Map<String, double>.from(
      (data['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );

    final topTags = tagScores.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dislikedTags = tagScores.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return {
      'hasPreferences': true,
      'totalSwipes': data['totalSwipes'] ?? 0,
      'topTags': topTags.take(10).map((e) => e.key).toList(),
      'topTagScores': Map.fromEntries(topTags.take(10)),
      'dislikedTags': dislikedTags.take(10).map((e) => e.key).toList(),
      'dislikedTagScores': Map.fromEntries(dislikedTags.take(10)),
      'likedFoodCount': (data['likedFoodIds'] as List?)?.length ?? 0,
      'dislikedFoodCount': (data['dislikedFoodIds'] as List?)?.length ?? 0,
      'userPreferences': data['userPreferences'],
    };
  }

  Future<void> resetPreferences(String uid) async {
    await _db.collection('preferences').doc(uid).delete();
  }

  Future<Map<String, double>> _getTagScores(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return {};

    final rawScores = Map<String, double>.from(
      (doc.data()?['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
    final updatedAt = Map<String, Timestamp>.from(
      doc.data()?['tagUpdatedAt'] as Map<String, dynamic>? ?? {},
    );

    final decayed = <String, double>{};
    for (final entry in rawScores.entries) {
      final score = _applyDecay(entry.value, updatedAt[entry.key]);
      if (score.abs() > 0.01) {
        decayed[entry.key] = score;
      }
    }
    return decayed;
  }

  Future<_PreferenceState> _loadPreferenceState(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    final data = doc.exists ? doc.data()! : _emptyPreferences();
    final userPreferences =
        data['userPreferences'] as Map<String, dynamic>? ?? {};
    final nestedTagPreference = _readScoreMap(userPreferences['tagPreference']);
    final topLevelTagScores = _readScoreMap(data['tagScores']);

    return _PreferenceState(
      ingredientPreference:
          _readScoreMap(userPreferences['ingredientPreference']),
      cuisinePreference:
          _readScoreMap(userPreferences['cuisinePreference']),
      tagPreference: nestedTagPreference.isEmpty
          ? topLevelTagScores
          : nestedTagPreference,
      macroPreference: _readScoreMap(userPreferences['macroPreference']),
      mealTypePreference:
          _readScoreMap(userPreferences['mealTypePreference']),
    );
  }

  Future<void> _recordPreferenceFeedback({
    required String uid,
    required _MealFeatures mealFeatures,
    required bool liked,
    required String likedId,
  }) async {
    final docRef = _db.collection('preferences').doc(uid);
    final doc = await docRef.get();
    final data = doc.exists ? doc.data()! : _emptyPreferences();
    final mutated = _copyPreferenceDocument(data);
    final delta = liked ? _swipeWeight : -_swipeWeight;

    _applyMealToPreferenceMaps(mutated, mealFeatures, delta);

    final likedIds = List<String>.from(mutated['likedFoodIds'] ?? []);
    final dislikedIds = List<String>.from(mutated['dislikedFoodIds'] ?? []);
    likedIds.remove(likedId);
    dislikedIds.remove(likedId);
    if (liked) {
      likedIds.add(likedId);
    } else {
      dislikedIds.add(likedId);
    }

    final history =
        List<Map<String, dynamic>>.from(mutated['swipeHistory'] ?? []);
    history.add({
      'foodId': likedId,
      'foodName': mealFeatures.name,
      'liked': liked,
      'ingredients': mealFeatures.ingredients,
      'cuisine': mealFeatures.cuisine,
      'tags': mealFeatures.tags,
      'macroTags': mealFeatures.macroTags,
      'mealType': mealFeatures.mealType,
      'timestamp': Timestamp.now(),
    });
    while (history.length > _maxSwipeHistory) {
      history.removeAt(0);
    }

    mutated['likedFoodIds'] = likedIds;
    mutated['dislikedFoodIds'] = dislikedIds;
    mutated['swipeHistory'] = history;
    mutated['totalSwipes'] = (mutated['totalSwipes'] ?? 0) + 1;
    mutated['lastUpdated'] = Timestamp.now();
    _refreshIngredientLists(mutated);

    await docRef.set(mutated, SetOptions(merge: true));
  }

  void _applyMealToPreferenceMaps(
    Map<String, dynamic> data,
    _MealFeatures mealFeatures,
    double delta,
  ) {
    final userPreferences =
        data['userPreferences'] as Map<String, dynamic>;
    final ingredientPreference =
        _readScoreMap(userPreferences['ingredientPreference']);
    final cuisinePreference =
        _readScoreMap(userPreferences['cuisinePreference']);
    final tagPreference = _readScoreMap(userPreferences['tagPreference']);
    final macroPreference =
        _readScoreMap(userPreferences['macroPreference']);
    final mealTypePreference =
        _readScoreMap(userPreferences['mealTypePreference']);
    final topLevelTagScores = _readScoreMap(data['tagScores']);
    final tagUpdatedAt = _readTimestampMap(data['tagUpdatedAt']);

    for (final ingredient in mealFeatures.ingredients) {
      _updateScoreMap(ingredientPreference, ingredient, delta);
    }

    _updateScoreMap(cuisinePreference, mealFeatures.cuisine, delta * _cuisineWeight);
    _updateScoreMap(
      mealTypePreference,
      mealFeatures.mealType,
      delta * _mealTypeWeight,
    );

    for (final tag in mealFeatures.tags) {
      _updateScoreMap(tagPreference, tag, delta);
      final normalizedTag = _normalizeKey(tag);
      final currentScore = topLevelTagScores[normalizedTag] ?? 0.0;
      final decayed = _applyDecay(currentScore, tagUpdatedAt[normalizedTag]);
      topLevelTagScores[normalizedTag] =
          (decayed + delta).clamp(-_maxScore, _maxScore).toDouble();
      tagUpdatedAt[normalizedTag] = Timestamp.now();
    }

    for (final macroTag in mealFeatures.macroTags) {
      _updateScoreMap(macroPreference, macroTag, delta * 0.8);
    }

    userPreferences['ingredientPreference'] = ingredientPreference;
    userPreferences['cuisinePreference'] = cuisinePreference;
    userPreferences['tagPreference'] = tagPreference;
    userPreferences['macroPreference'] = macroPreference;
    userPreferences['mealTypePreference'] = mealTypePreference;
    data['userPreferences'] = userPreferences;
    data['tagScores'] = topLevelTagScores;
    data['tagUpdatedAt'] = tagUpdatedAt;
  }

  void _applySerializedFeedback(
    Map<String, dynamic> data,
    Map<String, dynamic> feedback,
    double delta,
  ) {
    final userPreferences =
        data['userPreferences'] as Map<String, dynamic>;
    final ingredientPreference =
        _readScoreMap(userPreferences['ingredientPreference']);
    final cuisinePreference =
        _readScoreMap(userPreferences['cuisinePreference']);
    final tagPreference = _readScoreMap(userPreferences['tagPreference']);
    final macroPreference =
        _readScoreMap(userPreferences['macroPreference']);
    final mealTypePreference =
        _readScoreMap(userPreferences['mealTypePreference']);
    final topLevelTagScores = _readScoreMap(data['tagScores']);
    final tagUpdatedAt = _readTimestampMap(data['tagUpdatedAt']);

    for (final ingredient in List<String>.from(feedback['ingredients'] ?? [])) {
      _updateScoreMap(ingredientPreference, ingredient, delta);
    }
    _updateScoreMap(
      cuisinePreference,
      feedback['cuisine']?.toString() ?? '',
      delta * _cuisineWeight,
    );
    _updateScoreMap(
      mealTypePreference,
      feedback['mealType']?.toString() ?? '',
      delta * _mealTypeWeight,
    );

    for (final tag in List<String>.from(feedback['tags'] ?? [])) {
      _updateScoreMap(tagPreference, tag, delta);
      final normalizedTag = _normalizeKey(tag);
      final currentScore = topLevelTagScores[normalizedTag] ?? 0.0;
      final decayed = _applyDecay(currentScore, tagUpdatedAt[normalizedTag]);
      topLevelTagScores[normalizedTag] =
          (decayed + delta).clamp(-_maxScore, _maxScore).toDouble();
      tagUpdatedAt[normalizedTag] = Timestamp.now();
    }

    for (final tag in List<String>.from(feedback['macroTags'] ?? [])) {
      _updateScoreMap(macroPreference, tag, delta * 0.8);
    }

    userPreferences['ingredientPreference'] = ingredientPreference;
    userPreferences['cuisinePreference'] = cuisinePreference;
    userPreferences['tagPreference'] = tagPreference;
    userPreferences['macroPreference'] = macroPreference;
    userPreferences['mealTypePreference'] = mealTypePreference;
    data['userPreferences'] = userPreferences;
    data['tagScores'] = topLevelTagScores;
    data['tagUpdatedAt'] = tagUpdatedAt;
  }

  double _goalCompatibilityScore(
    _MealFeatures features,
    GoalProfile goalProfile,
  ) {
    switch (goalProfile.primaryGoal) {
      case NutritionGoalType.weightLoss:
        final maxCalories = _goalConstraints(features.mealType, goalProfile)['maxCalories']!;
        final maxFats = _goalConstraints(features.mealType, goalProfile)['maxFats']!;
        final maxGi = _goalConstraints(features.mealType, goalProfile)['maxGi']!;
        final calorieScore = 1 - (features.calories / maxCalories).clamp(0.0, 1.0);
        final fatScore = 1 - (features.fats / maxFats).clamp(0.0, 1.0);
        final giScore = 1 - (features.glycemicIndex / maxGi).clamp(0.0, 1.0);
        final proteinDensity =
            ((features.protein * 4) / (features.calories <= 0 ? 1 : features.calories))
                .clamp(0.0, 0.35) /
            0.35;
        return ((calorieScore * 0.35) +
                (fatScore * 0.20) +
                (giScore * 0.20) +
                (proteinDensity * 0.25))
            .clamp(0.0, 1.0);
      case NutritionGoalType.muscleGain:
        final constraints = _goalConstraints(features.mealType, goalProfile);
        final minCalories = constraints['minCalories']!;
        final minProtein = constraints['minProtein']!;
        final calorieScore = (features.calories / minCalories).clamp(0.0, 1.0);
        final proteinScore = (features.protein / minProtein).clamp(0.0, 1.0);
        final carbSupport = (features.carbs / 45).clamp(0.0, 1.0);
        final giPenalty = features.glycemicIndex >= 70 ? 0.1 : 0.0;
        return ((calorieScore * 0.30) +
                (proteinScore * 0.45) +
                (carbSupport * 0.25) -
                giPenalty)
            .clamp(0.0, 1.0);
      case NutritionGoalType.diabetes:
        final constraints = _goalConstraints(features.mealType, goalProfile);
        final maxCarbs = constraints['maxCarbs']!;
        final maxGi = constraints['maxGi']!;
        final giScore = 1 - (features.glycemicIndex / maxGi).clamp(0.0, 1.0);
        final carbScore = 1 - (features.carbs / maxCarbs).clamp(0.0, 1.0);
        final fiberProxy = features.tags.contains('high_fiber') ? 1.0 : 0.5;
        final proteinSupport = (features.protein / 25).clamp(0.0, 1.0);
        return ((giScore * 0.35) +
                (carbScore * 0.35) +
                (fiberProxy * 0.15) +
                (proteinSupport * 0.15))
            .clamp(0.0, 1.0);
      case NutritionGoalType.balanced:
        final midpoint = _mealTypeMidpoint(features.mealType);
        final calorieDistance =
            ((features.calories - midpoint).abs() / midpoint).clamp(0.0, 1.0);
        final proteinSupport = (features.protein / 20).clamp(0.0, 1.0);
        return ((1 - calorieDistance) * 0.55 + proteinSupport * 0.45)
            .clamp(0.0, 1.0);
    }
  }

  double _preferenceScore(
    _MealFeatures features,
    _PreferenceState preferences,
  ) {
    final ingredientScore =
        _normalizedAverageScore(features.ingredients, preferences.ingredientPreference);
    final cuisineScore =
        _normalizedSingleScore(features.cuisine, preferences.cuisinePreference);
    final tagScore =
        _normalizedAverageScore(features.tags, preferences.tagPreference);
    final macroScore =
        _normalizedAverageScore(features.macroTags, preferences.macroPreference);
    final mealTypeScore =
        _normalizedSingleScore(features.mealType, preferences.mealTypePreference);

    return ((ingredientScore * 0.30) +
            (cuisineScore * 0.20) +
            (tagScore * 0.20) +
            (macroScore * 0.15) +
            (mealTypeScore * 0.15))
        .clamp(0.0, 1.0);
  }

  bool _isGoalSafe(
    _MealFeatures features,
    GoalProfile goalProfile,
  ) {
    final constraints = _goalConstraints(features.mealType, goalProfile);
    final suitable = features.suitableFor;
    final tags = features.tags;

    switch (goalProfile.primaryGoal) {
      case NutritionGoalType.weightLoss:
        final semanticMatch = suitable.contains('weight_loss') ||
            tags.contains('low_calorie') ||
            tags.contains('low_fat');
        return semanticMatch &&
            features.calories <= constraints['maxCalories']! &&
            features.fats <= constraints['maxFats']! &&
            features.glycemicIndex <= constraints['maxGi']! &&
            features.carbs <= constraints['maxCarbs']!;
      case NutritionGoalType.muscleGain:
        final semanticMatch = suitable.contains('muscle_gain') ||
            tags.contains('high_protein');
        return semanticMatch &&
            features.protein >= constraints['minProtein']! &&
            features.calories >= constraints['minCalories']! &&
            features.glycemicIndex <= constraints['maxGi']!;
      case NutritionGoalType.diabetes:
        final semanticMatch =
            suitable.contains('diabetic') || tags.contains('low_gi');
        return semanticMatch &&
            features.glycemicIndex <= constraints['maxGi']! &&
            features.carbs <= constraints['maxCarbs']! &&
            features.calories <= constraints['maxCalories']!;
      case NutritionGoalType.balanced:
        return features.calories <= constraints['maxCalories']! &&
            features.glycemicIndex <= constraints['maxGi']!;
    }
  }

  Map<String, double> _goalConstraints(
    String mealType,
    GoalProfile goalProfile,
  ) {
    final type = _normalizeKey(mealType);

    switch (goalProfile.primaryGoal) {
      case NutritionGoalType.weightLoss:
        if (type == 'breakfast') {
          return {
            'maxCalories': 420,
            'maxFats': 18,
            'maxCarbs': 55,
            'maxGi': 55,
          };
        }
        if (type == 'lunch') {
          return {
            'maxCalories': 560,
            'maxFats': 22,
            'maxCarbs': 60,
            'maxGi': 58,
          };
        }
        if (type == 'dinner') {
          return {
            'maxCalories': 500,
            'maxFats': 22,
            'maxCarbs': 55,
            'maxGi': 55,
          };
        }
        return {
          'maxCalories': 220,
          'maxFats': 12,
          'maxCarbs': 26,
          'maxGi': 50,
        };
      case NutritionGoalType.muscleGain:
        if (type == 'breakfast') {
          return {
            'minCalories': 320,
            'minProtein': 18,
            'maxGi': 69,
          };
        }
        if (type == 'lunch') {
          return {
            'minCalories': 450,
            'minProtein': 28,
            'maxGi': 69,
          };
        }
        if (type == 'dinner') {
          return {
            'minCalories': 400,
            'minProtein': 28,
            'maxGi': 69,
          };
        }
        return {
          'minCalories': 180,
          'minProtein': 12,
          'maxGi': 60,
        };
      case NutritionGoalType.diabetes:
        if (type == 'breakfast') {
          return {
            'maxCalories': 450,
            'maxCarbs': 45,
            'maxGi': 55,
          };
        }
        if (type == 'lunch') {
          return {
            'maxCalories': 600,
            'maxCarbs': 55,
            'maxGi': 55,
          };
        }
        if (type == 'dinner') {
          return {
            'maxCalories': 550,
            'maxCarbs': 50,
            'maxGi': 55,
          };
        }
        return {
          'maxCalories': 220,
          'maxCarbs': 25,
          'maxGi': 45,
        };
      case NutritionGoalType.balanced:
        if (type == 'breakfast') {
          return {'maxCalories': 500, 'maxGi': 65};
        }
        if (type == 'lunch') {
          return {'maxCalories': 650, 'maxGi': 65};
        }
        if (type == 'dinner') {
          return {'maxCalories': 600, 'maxGi': 65};
        }
        return {'maxCalories': 260, 'maxGi': 60};
    }
  }

  double _mealTypeMidpoint(String mealType) {
    switch (_normalizeKey(mealType)) {
      case 'breakfast':
        return 375;
      case 'lunch':
        return 500;
      case 'dinner':
        return 430;
      case 'snack':
        return 170;
      default:
        return 350;
    }
  }

  _MealFeatures _featuresFromMealMap(Map<String, dynamic> meal) {
    final tags = <String>{
      ...List<String>.from(meal['tags'] ?? []),
      ...List<String>.from(meal['dietTags'] ?? []),
    }.map(_normalizeKey).where((t) => t.isNotEmpty).toList();

    final suitable = List<String>.from(meal['suitableFor'] ?? [])
        .map(_normalizeKey)
        .where((t) => t.isNotEmpty)
        .toList();

    final ingredients = <String>[];
    for (final ingredient in meal['ingredients'] as List? ?? const []) {
      if (ingredient is Map<String, dynamic>) {
        final name = ingredient['name']?.toString() ?? '';
        if (name.isNotEmpty) ingredients.add(_normalizeKey(name));
      } else if (ingredient is Map) {
        final name = ingredient['name']?.toString() ?? '';
        if (name.isNotEmpty) ingredients.add(_normalizeKey(name));
      } else if (ingredient is String) {
        ingredients.add(_normalizeKey(ingredient));
      }
    }

    final features = _MealFeatures(
      id: meal['id']?.toString() ?? '',
      name: meal['name']?.toString() ?? '',
      calories: (meal['calories'] as num?)?.toDouble() ?? 0,
      protein: (meal['protein'] as num?)?.toDouble() ?? 0,
      carbs: (meal['carbs'] as num?)?.toDouble() ?? 0,
      fats: (meal['fats'] as num?)?.toDouble() ?? 0,
      glycemicIndex: (meal['glycemicIndex'] as num?)?.toInt() ?? 0,
      mealType: meal['mealType']?.toString() ?? 'Lunch',
      cuisine: meal['cuisine']?.toString() ?? 'balanced',
      tags: tags,
      ingredients: ingredients,
      suitableFor: suitable,
    );
    return features.copyWith(
      macroTags: _macroTagsForMeal(
        calories: features.calories,
        protein: features.protein,
        carbs: features.carbs,
        fats: features.fats,
        glycemicIndex: features.glycemicIndex,
        mealType: features.mealType,
        tags: features.tags,
      ),
    );
  }

  _MealFeatures _featuresFromSwipeMeal(SwipeMeal meal) {
    final tags = meal.tags.map(_normalizeKey).where((t) => t.isNotEmpty).toList();
    final features = _MealFeatures(
      id: meal.id,
      name: meal.name,
      calories: meal.calories,
      protein: meal.protein,
      carbs: meal.carbs,
      fats: meal.fats,
      glycemicIndex: meal.glycemicIndex,
      mealType: meal.mealType,
      cuisine: meal.cuisine,
      tags: tags,
      ingredients: meal.mainIngredients
          .map(_normalizeKey)
          .where((t) => t.isNotEmpty)
          .toList(),
      suitableFor: const [],
    );
    return features.copyWith(
      macroTags: _macroTagsForMeal(
        calories: features.calories,
        protein: features.protein,
        carbs: features.carbs,
        fats: features.fats,
        glycemicIndex: features.glycemicIndex,
        mealType: features.mealType,
        tags: features.tags,
      ),
    );
  }

  List<String> _macroTagsForMeal({
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    required int glycemicIndex,
    required String mealType,
    required List<String> tags,
  }) {
    final macroTags = <String>{};
    final normalizedType = _normalizeKey(mealType);
    final proteinCalories = protein * 4;
    final calorieBase = calories <= 0 ? 1 : calories;

    if ((proteinCalories / calorieBase) >= 0.2 || protein >= 20) {
      macroTags.add('high_protein');
    }
    if (carbs <= 20) macroTags.add('low_carb');
    if (carbs >= 55) macroTags.add('high_carb');
    if (glycemicIndex <= 55) macroTags.add('low_gi');
    if (glycemicIndex >= 70) macroTags.add('high_gi');
    if (fats <= 12) macroTags.add('low_fat');

    final midpoint = _mealTypeMidpoint(normalizedType);
    if (calories <= midpoint) {
      macroTags.add('low_calorie');
    } else if (calories >= midpoint + 80) {
      macroTags.add('high_calorie');
    }

    macroTags.addAll(tags.where((t) =>
        t.contains('protein') ||
        t.contains('calorie') ||
        t.contains('carb') ||
        t.contains('gi') ||
        t.contains('fiber')));
    return macroTags.toList();
  }

  double _normalizedAverageScore(
    List<String> keys,
    Map<String, double> scoreMap,
  ) {
    if (keys.isEmpty || scoreMap.isEmpty) return 0.5;

    final normalizedKeys = keys.map(_normalizeKey).where((k) => k.isNotEmpty).toSet();
    if (normalizedKeys.isEmpty) return 0.5;

    double total = 0;
    for (final key in normalizedKeys) {
      total += scoreMap[key] ?? 0.0;
    }
    return _normalizeScore(total / normalizedKeys.length);
  }

  double _normalizedSingleScore(
    String key,
    Map<String, double> scoreMap,
  ) {
    if (key.isEmpty || scoreMap.isEmpty) return 0.5;
    return _normalizeScore(scoreMap[_normalizeKey(key)] ?? 0.0);
  }

  double _normalizeScore(double rawScore) {
    return (((rawScore / _maxScore) + 1) / 2).clamp(0.0, 1.0);
  }

  Map<String, double> _readScoreMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, double>.fromEntries(
        raw.entries.map(
          (entry) => MapEntry(
            _normalizeKey(entry.key.toString()),
            (entry.value as num).toDouble(),
          ),
        ),
      );
    }
    return <String, double>{};
  }

  Map<String, Timestamp> _readTimestampMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, Timestamp>.fromEntries(
        raw.entries.where((entry) => entry.value is Timestamp).map(
              (entry) => MapEntry(
                _normalizeKey(entry.key.toString()),
                entry.value as Timestamp,
              ),
            ),
      );
    }
    return <String, Timestamp>{};
  }

  void _updateScoreMap(
    Map<String, double> scoreMap,
    String key,
    double delta,
  ) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey.isEmpty) return;
    final current = scoreMap[normalizedKey] ?? 0.0;
    scoreMap[normalizedKey] =
        (current + delta).clamp(-_maxScore, _maxScore).toDouble();
  }

  void _refreshIngredientLists(Map<String, dynamic> data) {
    final userPreferences =
        data['userPreferences'] as Map<String, dynamic>;
    final ingredientPreference =
        _readScoreMap(userPreferences['ingredientPreference']);

    final sorted = ingredientPreference.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    userPreferences['likedIngredients'] = sorted
        .where((entry) => entry.value > 0)
        .take(20)
        .map((entry) => entry.key)
        .toList();
    final disliked = sorted.where((entry) => entry.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    userPreferences['dislikedIngredients'] =
        disliked.take(20).map((entry) => entry.key).toList();
    data['userPreferences'] = userPreferences;
  }

  Map<String, dynamic> _copyPreferenceDocument(Map<String, dynamic> source) {
    final tagScores = Map<String, double>.from(
      (source['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(_normalizeKey(k), (v as num).toDouble()),
      ),
    );
    final userPreferences =
        Map<String, dynamic>.from(source['userPreferences'] ?? _emptyUserPreferences());

    return {
      'tagScores': tagScores,
      'tagUpdatedAt': _readTimestampMap(source['tagUpdatedAt']),
      'likedFoodIds': List<String>.from(source['likedFoodIds'] ?? const []),
      'dislikedFoodIds':
          List<String>.from(source['dislikedFoodIds'] ?? const []),
      'swipeHistory': (source['swipeHistory'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(),
      'totalSwipes': source['totalSwipes'] ?? 0,
      'lastUpdated': source['lastUpdated'] ?? Timestamp.now(),
      'userPreferences': {
        'ingredientPreference': Map<String, double>.from(
          _readScoreMap(userPreferences['ingredientPreference']),
        ),
        'likedIngredients':
            List<String>.from(userPreferences['likedIngredients'] ?? const []),
        'dislikedIngredients':
            List<String>.from(userPreferences['dislikedIngredients'] ?? const []),
        'cuisinePreference': Map<String, double>.from(
          _readScoreMap(userPreferences['cuisinePreference']),
        ),
        'tagPreference': Map<String, double>.from(
          _readScoreMap(userPreferences['tagPreference']),
        ),
        'macroPreference': Map<String, double>.from(
          _readScoreMap(userPreferences['macroPreference']),
        ),
        'mealTypePreference': Map<String, double>.from(
          _readScoreMap(userPreferences['mealTypePreference']),
        ),
        'weeklyLearning':
            Map<String, dynamic>.from(userPreferences['weeklyLearning'] ?? const {}),
      },
    };
  }

  double _applyDecay(double score, Timestamp? lastUpdated) {
    if (lastUpdated == null || score == 0) return score;

    final daysSinceUpdate =
        DateTime.now().difference(lastUpdated.toDate()).inDays;
    if (daysSinceUpdate <= _decayAfterDays) return score;

    final decayPeriods = (daysSinceUpdate / _decayAfterDays).floor();
    var decayed = score;
    for (int i = 0; i < decayPeriods; i++) {
      decayed *= _decayFactor;
    }
    return decayed;
  }

  double _calculateFoodScore(FoodItem food, Map<String, double> tagScores) {
    if (food.tags.isEmpty) return 0.0;
    double total = 0.0;
    for (final tag in food.tags) {
      total += tagScores[_normalizeKey(tag)] ?? 0.0;
    }
    return total / food.tags.length;
  }

  Map<String, dynamic> _emptyPreferences() {
    return {
      'tagScores': <String, double>{},
      'tagUpdatedAt': <String, Timestamp>{},
      'likedFoodIds': <String>[],
      'dislikedFoodIds': <String>[],
      'swipeHistory': <Map<String, dynamic>>[],
      'totalSwipes': 0,
      'lastUpdated': Timestamp.now(),
      'userPreferences': _emptyUserPreferences(),
    };
  }

  Map<String, dynamic> _emptyUserPreferences() {
    return {
      'ingredientPreference': <String, double>{},
      'likedIngredients': <String>[],
      'dislikedIngredients': <String>[],
      'cuisinePreference': <String, double>{},
      'tagPreference': <String, double>{},
      'macroPreference': <String, double>{},
      'mealTypePreference': <String, double>{},
      'weeklyLearning': <String, dynamic>{},
    };
  }

  String _normalizeKey(String value) {
    return value.trim().toLowerCase();
  }
}

class ScoredFood {
  final FoodItem food;
  final double score;

  const ScoredFood({required this.food, required this.score});
}

class _PreferenceState {
  final Map<String, double> ingredientPreference;
  final Map<String, double> cuisinePreference;
  final Map<String, double> tagPreference;
  final Map<String, double> macroPreference;
  final Map<String, double> mealTypePreference;

  const _PreferenceState({
    required this.ingredientPreference,
    required this.cuisinePreference,
    required this.tagPreference,
    required this.macroPreference,
    required this.mealTypePreference,
  });
}

class _MealFeatures {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final int glycemicIndex;
  final String mealType;
  final String cuisine;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> suitableFor;
  final List<String> macroTags;

  const _MealFeatures({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.glycemicIndex,
    required this.mealType,
    required this.cuisine,
    required this.tags,
    required this.ingredients,
    required this.suitableFor,
    this.macroTags = const [],
  });

  _MealFeatures copyWith({
    List<String>? macroTags,
  }) {
    return _MealFeatures(
      id: id,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      glycemicIndex: glycemicIndex,
      mealType: mealType,
      cuisine: cuisine,
      tags: tags,
      ingredients: ingredients,
      suitableFor: suitableFor,
      macroTags: macroTags ?? this.macroTags,
    );
  }
}
