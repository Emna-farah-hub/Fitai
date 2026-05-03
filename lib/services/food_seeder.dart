import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Seeds Firestore with common foods and Tunisian dishes if not already seeded.
/// Re-seeds if existing docs are missing the 'tags' field.
Future<void> seedAllFoods() async {
  final firestore = FirebaseFirestore.instance;

  // Check if existing docs have tags — if not, force re-seed
  bool needsReseed = false;
  try {
    final sample = await firestore.collection('common_foods').limit(1).get();
    if (sample.docs.isNotEmpty) {
      final data = sample.docs.first.data();
      if (data['tags'] == null || (data['tags'] as List).isEmpty) {
        needsReseed = true;
      }
    }
  } catch (_) {}

  // 1. Check & seed common_foods
  final commonSnap = await firestore.collection('common_foods').limit(10).get();
  final commonAlreadySeeded = commonSnap.docs.length >= 10 && !needsReseed;

  // 2. Check & seed tunisian_foods
  bool tunisianNeedsReseed = false;
  try {
    final sample = await firestore.collection('tunisian_foods').limit(1).get();
    if (sample.docs.isNotEmpty) {
      final data = sample.docs.first.data();
      if (data['tags'] == null || (data['tags'] as List).isEmpty) {
        tunisianNeedsReseed = true;
      }
    }
  } catch (_) {}

  final tunisianSnap = await firestore.collection('tunisian_foods').limit(5).get();
  final tunisianAlreadySeeded = tunisianSnap.docs.length >= 5 && !tunisianNeedsReseed;

  if (commonAlreadySeeded && tunisianAlreadySeeded) {
    return;
  }

  // Seed common foods from JSON asset
  if (!commonAlreadySeeded) {
    // Delete old docs without tags
    if (needsReseed) {
      final allDocs = await firestore.collection('common_foods').get();
      final deleteBatch = firestore.batch();
      for (final doc in allDocs.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    final jsonString = await rootBundle.loadString('assets/common_foods.json');
    final List<dynamic> foods = json.decode(jsonString);

    // Firestore batch limit is 500 — split if needed
    final batch = firestore.batch();
    for (final food in foods) {
      final docRef = firestore.collection('common_foods').doc(food['id']);
      batch.set(docRef, Map<String, dynamic>.from(food));
    }
    await batch.commit();
  }

  // Seed Tunisian foods
  if (!tunisianAlreadySeeded) {
    if (tunisianNeedsReseed) {
      final allDocs = await firestore.collection('tunisian_foods').get();
      final deleteBatch = firestore.batch();
      for (final doc in allDocs.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    final tunisianFoods = [
      {'id': 'tn001', 'name': 'Couscous (agneau)', 'caloriesPer100g': 195, 'protein': 8, 'carbs': 28, 'fats': 5, 'glycemicIndex': 65, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['lamb', 'meat', 'grain', 'prepared', 'high_carb', 'medium_gi', 'needs_cooking', 'hot', 'savory', 'lunch', 'dinner', 'tunisian', 'comfort_food', 'filling']},
      {'id': 'tn002', 'name': 'Brik (thon)', 'caloriesPer100g': 210, 'protein': 9, 'carbs': 18, 'fats': 12, 'glycemicIndex': 55, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['fish', 'prepared', 'medium_gi', 'needs_cooking', 'hot', 'savory', 'lunch', 'tunisian', 'comfort_food']},
      {'id': 'tn003', 'name': 'Lablebi', 'caloriesPer100g': 140, 'protein': 7, 'carbs': 22, 'fats': 3, 'glycemicIndex': 28, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['legume', 'prepared', 'plant_protein', 'low_gi', 'needs_cooking', 'hot', 'savory', 'breakfast', 'lunch', 'tunisian', 'comfort_food', 'filling', 'spicy']},
      {'id': 'tn004', 'name': 'Chorba frik', 'caloriesPer100g': 85, 'protein': 6, 'carbs': 12, 'fats': 2, 'glycemicIndex': 45, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['grain', 'prepared', 'low_calorie', 'low_gi', 'needs_cooking', 'hot', 'savory', 'dinner', 'tunisian', 'comfort_food', 'light']},
      {'id': 'tn005', 'name': 'Ojja (merguez)', 'caloriesPer100g': 175, 'protein': 10, 'carbs': 8, 'fats': 12, 'glycemicIndex': 35, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['meat', 'eggs', 'prepared', 'low_gi', 'needs_cooking', 'hot', 'savory', 'spicy', 'lunch', 'dinner', 'tunisian', 'comfort_food']},
      {'id': 'tn006', 'name': 'Kafteji', 'caloriesPer100g': 160, 'protein': 7, 'carbs': 14, 'fats': 9, 'glycemicIndex': 50, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['vegetable', 'prepared', 'low_gi', 'needs_cooking', 'hot', 'savory', 'lunch', 'dinner', 'tunisian', 'comfort_food']},
      {'id': 'tn007', 'name': 'Fricasse', 'caloriesPer100g': 280, 'protein': 8, 'carbs': 32, 'fats': 14, 'glycemicIndex': 70, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['prepared', 'high_carb', 'high_calorie', 'high_gi', 'needs_cooking', 'hot', 'savory', 'lunch', 'snack', 'tunisian', 'comfort_food', 'filling']},
      {'id': 'tn008', 'name': 'Mechouia', 'caloriesPer100g': 90, 'protein': 3, 'carbs': 8, 'fats': 5, 'glycemicIndex': 40, 'isTunisian': true, 'source': 'local', 'category': 'prepared', 'tags': ['vegetable', 'prepared', 'low_calorie', 'low_gi', 'cold', 'savory', 'spicy', 'lunch', 'dinner', 'tunisian', 'light', 'mediterranean']},
    ];

    final batch = firestore.batch();
    for (final food in tunisianFoods) {
      final docRef = firestore.collection('tunisian_foods').doc(food['id'] as String);
      batch.set(docRef, food);
    }
    await batch.commit();
  }

  // 3. Check & seed tunisian_meals (full meal database for plan generation)
  final tunisianMealsSnap =
      await firestore.collection('tunisian_meals').limit(5).get();
  final tunisianMealsAlreadySeeded = tunisianMealsSnap.docs.length >= 5;

  if (!tunisianMealsAlreadySeeded) {
    final jsonString =
        await rootBundle.loadString('assets/Tunisian_meals.json');
    final List<dynamic> meals = json.decode(jsonString);

    for (int i = 0; i < meals.length; i += 20) {
      final batch = firestore.batch();
      final end = (i + 20) > meals.length ? meals.length : i + 20;
      for (final meal in meals.sublist(i, end)) {
        final docRef = firestore
            .collection('tunisian_meals')
            .doc(meal['id'] as String);
        batch.set(docRef, Map<String, dynamic>.from(meal as Map));
      }
      await batch.commit();
    }
    debugPrint('Seeded ${meals.length} tunisian meals');
  }
}
