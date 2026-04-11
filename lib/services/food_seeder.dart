import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// Seeds Firestore with common foods and Tunisian dishes if not already seeded.
Future<void> seedAllFoods() async {
  final firestore = FirebaseFirestore.instance;

  // 1. Check & seed common_foods
  final commonSnap = await firestore.collection('common_foods').limit(10).get();
  final commonAlreadySeeded = commonSnap.docs.length >= 10;

  // 2. Check & seed tunisian_foods
  final tunisianSnap = await firestore.collection('tunisian_foods').limit(5).get();
  final tunisianAlreadySeeded = tunisianSnap.docs.length >= 5;

  if (commonAlreadySeeded && tunisianAlreadySeeded) {
    print('⏭ Already seeded — skipping');
    return;
  }

  // Seed common foods from JSON asset
  if (!commonAlreadySeeded) {
    final jsonString = await rootBundle.loadString('assets/common_foods.json');
    final List<dynamic> foods = json.decode(jsonString);

    final batch = firestore.batch();
    for (final food in foods) {
      final docRef = firestore.collection('common_foods').doc(food['id']);
      batch.set(docRef, Map<String, dynamic>.from(food));
    }
    await batch.commit();
    print('✅ Seeded ${foods.length} common foods');
  }

  // Seed Tunisian foods
  if (!tunisianAlreadySeeded) {
    final tunisianFoods = [
      {'id': 'tn001', 'name': 'Couscous (agneau)', 'caloriesPer100g': 195, 'protein': 8, 'carbs': 28, 'fats': 5, 'glycemicIndex': 65, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn002', 'name': 'Brik (thon)', 'caloriesPer100g': 210, 'protein': 9, 'carbs': 18, 'fats': 12, 'glycemicIndex': 55, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn003', 'name': 'Lablebi', 'caloriesPer100g': 140, 'protein': 7, 'carbs': 22, 'fats': 3, 'glycemicIndex': 28, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn004', 'name': 'Chorba frik', 'caloriesPer100g': 85, 'protein': 6, 'carbs': 12, 'fats': 2, 'glycemicIndex': 45, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn005', 'name': 'Ojja (merguez)', 'caloriesPer100g': 175, 'protein': 10, 'carbs': 8, 'fats': 12, 'glycemicIndex': 35, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn006', 'name': 'Kafteji', 'caloriesPer100g': 160, 'protein': 7, 'carbs': 14, 'fats': 9, 'glycemicIndex': 50, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn007', 'name': 'Fricasse', 'caloriesPer100g': 280, 'protein': 8, 'carbs': 32, 'fats': 14, 'glycemicIndex': 70, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
      {'id': 'tn008', 'name': 'Mechouia', 'caloriesPer100g': 90, 'protein': 3, 'carbs': 8, 'fats': 5, 'glycemicIndex': 40, 'isTunisian': true, 'source': 'local', 'category': 'prepared'},
    ];

    final batch = firestore.batch();
    for (final food in tunisianFoods) {
      final docRef = firestore.collection('tunisian_foods').doc(food['id'] as String);
      batch.set(docRef, food);
    }
    await batch.commit();
    print('✅ Seeded ${tunisianFoods.length} Tunisian foods');
  }

  print('✅ Seeding complete');
}
