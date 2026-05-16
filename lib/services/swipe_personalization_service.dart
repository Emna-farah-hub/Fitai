import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal.dart';
import 'food_scoring_service.dart';
import 'meal_catalog_service.dart';

/// Builds a personalized batch of swipe meals for a user and persists the
/// batch's lifecycle (generated → seen → completed) in Firestore at
/// `users/{uid}/swipeState/current`.
///
/// Catalog filtering + safety lives in [MealCatalogService]. Scoring lives
/// in [FoodScoringService]. This service is the orchestrator that combines
/// them into a tier-based cascade and writes the durable batch document.
class SwipePersonalizationService {
  static final SwipePersonalizationService _instance =
      SwipePersonalizationService._internal();
  factory SwipePersonalizationService() => _instance;
  SwipePersonalizationService._internal();

  static const int _batchSize = 15;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MealCatalogService _catalog = MealCatalogService();
  final FoodScoringService _scoring = FoodScoringService();

  /// Tier-2 fallback: which granular cuisines are considered "adjacent" to
  /// a user's selected cuisine when the primary pool can't fill 15 cards.
  static const Map<String, List<String>> _adjacentCuisines = {
    'mediterranean': [
      'middle_eastern',
      'turkish',
      'spanish',
      'greek',
      'lebanese',
    ],
    'tunisian': ['mediterranean', 'middle_eastern'],
    'chinese': ['thai', 'korean', 'japanese', 'vietnamese'],
    'thai': ['chinese', 'korean', 'japanese', 'vietnamese'],
    'korean': ['chinese', 'thai', 'japanese', 'vietnamese'],
    'japanese': ['chinese', 'thai', 'korean', 'vietnamese'],
    'vietnamese': ['chinese', 'thai', 'korean', 'japanese'],
    'mexican': ['cuban', 'venezuelan', 'spanish'],
    'indian': ['middle_eastern', 'persian'],
  };

  /// Builds, persists, and returns a fresh batch of up to 15 personalized
  /// meals for the user.
  ///
  /// `learnedPreferences` is accepted to match the agreed signature but is
  /// not used directly — [FoodScoringService.rankMealMaps] re-loads the
  /// user's preference document from Firestore as part of its scoring pass.
  Future<List<Meal>> buildSwipeBatch({
    required dynamic userProfile,
    required Set<String> swipedMealIds,
    required dynamic learnedPreferences,
  }) async {
    await _catalog.initialize();

    final uid = _uidFromProfile(userProfile);
    if (uid.isEmpty) {
      throw StateError(
        'SwipePersonalizationService.buildSwipeBatch: userProfile is missing a uid.',
      );
    }

    final cuisinePreferences =
        _profileStringList(userProfile, 'cuisinePreferences');
    final goals = _profileStringList(userProfile, 'goals');
    final conditions = _profileStringList(userProfile, 'conditions');

    final selectedCuisines = _catalog
        .expandCuisines(cuisinePreferences)
        .map(_normalizeCuisine)
        .toSet();

    final adjacentCuisines = <String>{};
    for (final cuisine in selectedCuisines) {
      adjacentCuisines.addAll(_adjacentCuisines[cuisine] ?? const []);
    }
    adjacentCuisines.removeAll(selectedCuisines);

    final excludeIds = Set<String>.from(swipedMealIds);
    final allSafe = _catalog
        .getAll()
        .where((meal) =>
            !excludeIds.contains(meal.id) &&
            _catalog.passesSafetyFilter(meal, userProfile))
        .toList();

    if (allSafe.isEmpty) {
      await _saveBatch(uid, const []);
      return const [];
    }

    final ranked = await _scoring.rankMealMaps(
      uid: uid,
      meals: allSafe.map(_toScoringMap).toList(),
      goals: goals,
      conditions: conditions,
    );

    final tier1 = <Meal>[];
    final tier2 = <Meal>[];
    final tier3 = <Meal>[];
    for (final entry in ranked) {
      final id = entry.meal['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final meal = _catalog.getById(id);
      if (meal == null) continue;
      final cuisine = _normalizeCuisine(meal.cuisine);
      if (selectedCuisines.contains(cuisine)) {
        tier1.add(meal);
      } else if (adjacentCuisines.contains(cuisine)) {
        tier2.add(meal);
      } else {
        tier3.add(meal);
      }
    }

    final batch = <Meal>[];
    final batchIds = <String>{};
    for (final meal in [...tier1, ...tier2, ...tier3]) {
      if (batch.length >= _batchSize) break;
      if (batchIds.add(meal.id)) batch.add(meal);
    }

    await _saveBatch(uid, batch);
    return batch;
  }

  /// Returns the currently active batch if one exists and is not yet marked
  /// complete. Returns null when there is no active batch.
  Future<List<Meal>?> loadExistingBatch(String uid) async {
    await _catalog.initialize();
    final doc = await _batchDoc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    if (data['completedAt'] != null) return null;

    final ids = List<String>.from(data['batchMealIds'] ?? const []);
    if (ids.isEmpty) return null;

    final meals = <Meal>[];
    for (final id in ids) {
      final meal = _catalog.getById(id);
      if (meal != null) meals.add(meal);
    }
    return meals.isEmpty ? null : meals;
  }

  /// Appends [mealId] to the current batch's `seenIds` array.
  Future<void> markMealSeen(String uid, String mealId) async {
    await _batchDoc(uid).set({
      'seenIds': FieldValue.arrayUnion([mealId]),
    }, SetOptions(merge: true));
  }

  /// Marks the current batch as complete by stamping `completedAt`.
  Future<void> completeBatch(String uid) async {
    await _batchDoc(uid).set({
      'completedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveBatch(String uid, List<Meal> batch) async {
    await _batchDoc(uid).set({
      'batchMealIds': batch.map((m) => m.id).toList(),
      'generatedAt': Timestamp.now(),
      'seenIds': <String>[],
      'completedAt': null,
    });
  }

  DocumentReference<Map<String, dynamic>> _batchDoc(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('swipeState')
        .doc('current');
  }

  /// Shapes a [Meal] into the map format [FoodScoringService.rankMealMaps]
  /// expects. Keeps ingredient names as plain strings — the scoring layer
  /// already handles both string and object ingredient shapes.
  Map<String, dynamic> _toScoringMap(Meal meal) {
    return {
      'id': meal.id,
      'name': meal.name,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fats': meal.fats,
      'glycemicIndex': meal.glycemicIndex ?? 0,
      'mealType': meal.mealType,
      'cuisine': meal.cuisine,
      'tags': meal.tags,
      'dietTags': meal.dietTags,
      'suitableFor': meal.suitableFor,
      'ingredients': meal.ingredients,
    };
  }

  static String _uidFromProfile(dynamic profile) {
    if (profile == null) return '';
    if (profile is Map) return profile['uid']?.toString() ?? '';
    try {
      return profile.uid?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static List<String> _profileStringList(dynamic profile, String key) {
    final raw = _readProfileField(profile, key);
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static dynamic _readProfileField(dynamic profile, String key) {
    if (profile == null) return null;
    if (profile is Map) return profile[key];
    try {
      switch (key) {
        case 'cuisinePreferences':
          return profile.cuisinePreferences;
        case 'goals':
          return profile.goals;
        case 'conditions':
          return profile.conditions;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static String _normalizeCuisine(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }
}
