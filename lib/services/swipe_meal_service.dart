import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/swipe_meal.dart';

/// Loads meals from the JSON asset and tracks which meals each user
/// has already swiped on. Complements FoodScoringService (which handles
/// the preference math) by handling the meal catalogue + dedup state.
class SwipeMealService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<SwipeMeal>? _cachedMeals;

  /// Loads the full meal catalogue from assets (cached after first call).
  Future<List<SwipeMeal>> getAllMeals() async {
    if (_cachedMeals != null) return _cachedMeals!;

    final raw = await rootBundle.loadString('assets/swipe_meals.json');
    final List<dynamic> list = json.decode(raw) as List<dynamic>;
    _cachedMeals = list
        .map((m) => SwipeMeal.fromMap(m as Map<String, dynamic>))
        .toList();
    return _cachedMeals!;
  }

  /// Returns meals the user hasn't swiped on yet, shuffled.
  /// If [limit] is provided, trims to that many meals (for onboarding).
  Future<List<SwipeMeal>> getUnswipedMeals({
    required String uid,
    int? limit,
  }) async {
    final results = await Future.wait([
      getAllMeals(),
      _getSwipedMealIds(uid),
    ]);
    final all = results[0] as List<SwipeMeal>;
    final swiped = Set<String>.from(results[1] as List<String>);

    final unswiped = all.where((m) => !swiped.contains(m.id)).toList();
    unswiped.shuffle(Random());

    if (limit != null && unswiped.length > limit) {
      return unswiped.sublist(0, limit);
    }
    return unswiped;
  }

  /// Records that this user has swiped on [mealId] so it won't reappear.
  Future<void> markMealAsSwiped(String uid, String mealId) async {
    await _db.collection('preferences').doc(uid).set({
      'swipedMealIds': FieldValue.arrayUnion([mealId]),
    }, SetOptions(merge: true));
  }

  Future<List<String>> _getSwipedMealIds(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['swipedMealIds'] ?? []);
  }
}
