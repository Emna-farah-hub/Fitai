import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class FoodSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<FoodItem>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Step 1: Search local Firestore first
      final localResults = await _searchLocal(query);

      // Step 2: If local has 3 or more results, return local only
      if (localResults.length >= 3) return localResults;

      // Step 3: Also call OpenFoodFacts to fill the gap
      final apiResults = await _searchOpenFoodFacts(query);

      // Step 4: Merge — local first, then API, remove duplicates by name
      final seen = <String>{};
      final merged = <FoodItem>[];
      for (final item in [...localResults, ...apiResults]) {
        if (seen.add(item.name.toLowerCase())) merged.add(item);
      }
      return merged;
    } catch (_) {
      return [];
    }
  }

  Future<List<FoodItem>> _searchLocal(String query) async {
    try {
      final tunisianSnap =
          await _firestore.collection('tunisian_foods').get();
      final commonSnap = await _firestore.collection('common_foods').get();

      final tunisian = tunisianSnap.docs
          .map((doc) => FoodItem.fromMap(doc.data()))
          .toList();
      final common = commonSnap.docs
          .map((doc) => FoodItem.fromMap(doc.data()))
          .toList();

      final q = query.toLowerCase().trim();
      final results = <FoodItem>[];
      final seen = <String>{};

      // Tunisian first, then common, deduplicated by id
      for (final item in [...tunisian, ...common]) {
        if (item.name.toLowerCase().contains(q) && seen.add(item.id)) {
          results.add(item);
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<FoodItem>> _searchOpenFoodFacts(String query) async {
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&json=1&page_size=8'
        '&fields=product_name,nutriments',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List<dynamic>? ?? [];

      final results = <FoodItem>[];

      for (final product in products) {
        final name = product['product_name'];
        if (name == null || (name as String).trim().isEmpty) continue;

        final nutriments =
            product['nutriments'] as Map<String, dynamic>? ?? {};

        final calories =
            (nutriments['energy-kcal_100g'] ?? 0).toDouble();
        if (calories == 0) continue;

        final protein = (nutriments['proteins_100g'] ?? 0).toDouble();
        final carbs =
            (nutriments['carbohydrates_100g'] ?? 0).toDouble();
        final fats = (nutriments['fat_100g'] ?? 0).toDouble();

        results.add(FoodItem(
          id: 'off_${name.replaceAll(' ', '_')}',
          name: name.trim(),
          caloriesPer100g: calories,
          protein: protein,
          carbs: carbs,
          fats: fats,
          glycemicIndex: 0,
          isTunisian: false,
          source: 'openfoodfacts',
          category: 'international',
        ));
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<FoodItem>> getAll() async {
    try {
      final tunisianSnap =
          await _firestore.collection('tunisian_foods').get();
      final commonSnap = await _firestore.collection('common_foods').get();

      final tunisian = tunisianSnap.docs
          .map((doc) => FoodItem.fromMap(doc.data()))
          .toList();
      final common = commonSnap.docs
          .map((doc) => FoodItem.fromMap(doc.data()))
          .toList();

      // Tunisian first, then common, deduplicated by id
      final seen = <String>{};
      final results = <FoodItem>[];
      for (final item in [...tunisian, ...common]) {
        if (seen.add(item.id)) {
          results.add(item);
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
