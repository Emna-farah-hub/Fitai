import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/meal.dart';

/// In-memory catalog of every meal shipped in `assets/production_meals_v2.json`.
///
/// Loads the asset exactly once and serves the parsed `Meal` list to the
/// personalization layer. Holds no Firestore state and does no scoring —
/// callers compose those concerns on top of this catalog.
class MealCatalogService {
  static final MealCatalogService _instance = MealCatalogService._internal();
  factory MealCatalogService() => _instance;
  MealCatalogService._internal();

  static const String _assetPath = 'assets/production_meals_v2.json';

  /// Maps user-facing cuisine labels (as stored in the profile's
  /// `cuisinePreferences`) to the granular `cuisine` values used in the
  /// production meal catalog.
  static const Map<String, List<String>> cuisineExpansion = {
    'Tunisian': ['tunisian'],
    'Mediterranean': [
      'mediterranean',
      'greek',
      'spanish',
      'turkish',
      'lebanese',
    ],
    'Middle Eastern': ['middle_eastern', 'turkish', 'lebanese', 'persian'],
    'French': ['french'],
    'Italian': ['italian'],
    'Asian': ['chinese', 'thai', 'korean', 'japanese', 'vietnamese'],
    'Mexican': ['mexican', 'cuban', 'venezuelan'],
    'Indian': ['indian'],
    'International': ['international', 'american', 'fusion'],
  };

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Meal>? _cache;
  List<Map<String, dynamic>>? _rawCache;
  Future<List<Meal>>? _loading;

  /// Loads and parses the catalog. Safe to call multiple times — the asset
  /// is only read once.
  Future<void> initialize() async {
    await _load();
  }

  /// Returns the full catalog, loading it lazily on first access.
  List<Meal> getAll() {
    final cache = _cache;
    if (cache == null) {
      throw StateError(
        'MealCatalogService.getAll() called before initialize(). '
        'Await MealCatalogService().initialize() first.',
      );
    }
    return List.unmodifiable(cache);
  }

  /// Returns the raw production catalog shaped for the planner/scoring
  /// pipeline. Unlike [Meal], this preserves ingredient objects so callers
  /// like [FoodScoringService.rankMealMaps] can keep their current contract.
  List<Map<String, dynamic>> getAllMealMaps() {
    final cache = _rawCache;
    if (cache == null) {
      throw StateError(
        'MealCatalogService.getAllMealMaps() called before initialize(). '
        'Await MealCatalogService().initialize() first.',
      );
    }
    return List.unmodifiable(cache.map(_cloneMealMap).toList(growable: false));
  }

  Meal? getById(String id) {
    final cache = _cache;
    if (cache == null) return null;
    for (final meal in cache) {
      if (meal.id == id) return meal;
    }
    return null;
  }

  /// Returns meals matching the given filters. All arguments are optional;
  /// a null/empty value is treated as "no constraint".
  ///
  /// `cuisines` is matched against the catalog after expanding through
  /// [cuisineExpansion] — pass user-facing labels like 'Mediterranean'.
  List<Meal> getFiltered({
    List<String>? cuisines,
    Set<String>? excludeIds,
    String? dietaryPreference,
    bool? diabetesSafe,
    int? maxCalories,
  }) {
    final cache = _cache;
    if (cache == null) return const [];

    final allowedCuisines = (cuisines == null || cuisines.isEmpty)
        ? null
        : expandCuisines(cuisines).map(_normalizeCuisine).toSet();
    final normalizedDiet = dietaryPreference?.trim().toLowerCase();

    return cache.where((meal) {
      if (excludeIds != null && excludeIds.contains(meal.id)) return false;

      if (allowedCuisines != null &&
          !allowedCuisines.contains(_normalizeCuisine(meal.cuisine))) {
        return false;
      }

      if (normalizedDiet == 'vegan') {
        if (!_containsIgnoreCase(meal.dietTags, 'vegan')) return false;
      } else if (normalizedDiet == 'vegetarian') {
        if (!_containsIgnoreCase(meal.dietTags, 'vegetarian') &&
            !_containsIgnoreCase(meal.dietTags, 'vegan')) {
          return false;
        }
      }

      if (diabetesSafe == true) {
        final gi = meal.glycemicIndex;
        if (gi != null && gi > 55) return false;
      }

      if (maxCalories != null && meal.calories > maxCalories) return false;

      return true;
    }).toList();
  }

  /// Returns true when [meal] does not violate any hard dietary rule from
  /// [userProfile]. Soft preferences (goals, non-diabetes conditions, cuisine
  /// affinity) are handled by the scoring layer instead.
  ///
  /// Accepts either a `UserProfile` instance or a raw Firestore map.
  bool passesSafetyFilter(Meal meal, dynamic userProfile) {
    if (userProfile == null) return true;

    final allergies = _profileStringList(userProfile, 'allergies');
    final avoidFoods = _profileStringList(userProfile, 'avoidFoods');
    final dietaryPreference = _profileString(
      userProfile,
      'dietaryPreference',
    ).toLowerCase();
    final conditions = _profileStringList(
      userProfile,
      'conditions',
    ).map((c) => c.toLowerCase()).toList();

    final ingredientsLower = meal.ingredients
        .map((i) => i.toLowerCase())
        .toList();

    for (final allergy in allergies) {
      final needle = allergy.trim().toLowerCase();
      if (needle.isEmpty || needle == 'none') continue;
      if (ingredientsLower.any((ing) => ing.contains(needle))) return false;
    }

    for (final avoid in avoidFoods) {
      final needle = avoid.trim().toLowerCase();
      if (needle.isEmpty || needle == 'none') continue;
      if (ingredientsLower.any((ing) => ing.contains(needle))) return false;
    }

    if (dietaryPreference == 'vegan') {
      if (!_containsIgnoreCase(meal.dietTags, 'vegan')) return false;
    } else if (dietaryPreference == 'vegetarian') {
      if (!_containsIgnoreCase(meal.dietTags, 'vegetarian') &&
          !_containsIgnoreCase(meal.dietTags, 'vegan')) {
        return false;
      }
    }

    final hasDiabetes = conditions.any((c) => c.contains('diabetes'));
    if (hasDiabetes) {
      final gi = meal.glycemicIndex;
      if (gi != null && gi > 55) return false;
    }

    return true;
  }

  /// Expands user-facing cuisine labels into the granular cuisine strings
  /// stored on each `Meal`. Unknown labels are passed through as a single
  /// lowercased entry so custom values still match by exact name.
  List<String> expandCuisines(List<String> userCuisinePreferences) {
    final expanded = <String>{};
    for (final pref in userCuisinePreferences) {
      final mapped = cuisineExpansion[pref];
      if (mapped != null) {
        expanded.addAll(mapped);
      } else {
        final fallback = pref.trim().toLowerCase().replaceAll(' ', '_');
        if (fallback.isNotEmpty && fallback != 'none') {
          expanded.add(fallback);
        }
      }
    }
    return expanded.toList();
  }

  Future<List<Meal>> _load() {
    if (_cache != null) return Future.value(_cache!);
    return _loading ??= _loadAndApplyOverrides();
  }

  Future<List<Meal>> _loadAndApplyOverrides() async {
    try {
      final rawMeals = await _readAssetMaps();
      _rawCache = rawMeals;
      final meals = rawMeals.map(Meal.fromJson).toList(growable: false);
      _cache = meals;
      await _applyImageOverrides();
      return meals;
    } finally {
      _loading = null;
    }
  }

  Future<List<Map<String, dynamic>>> _readAssetMaps() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map(
          (entry) => _normalizeMealMap(
            Map<String, dynamic>.from(
              entry.map(
                (key, value) =>
                    MapEntry(key.toString(), _cloneJsonValue(value)),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  /// Reads `config/mealImages.urls` from Firestore and merges any matching
  /// `{mealId: url}` entries into the cached catalog via [Meal.copyWith].
  ///
  /// Firestore overrides win over `imageUrl` values bundled in the JSON, so
  /// photos can be updated without shipping a new app build. Fails soft —
  /// if the document is missing or the network is down the catalog keeps
  /// whatever it parsed from the asset.
  Future<void> _applyImageOverrides() async {
    final cache = _cache;
    final rawCache = _rawCache;
    if (cache == null) return;
    try {
      final doc = await _db.collection('config').doc('mealImages').get();
      if (!doc.exists) return;
      final raw = doc.data()?['urls'];
      if (raw is! Map) return;
      for (var i = 0; i < cache.length; i++) {
        final override = raw[cache[i].id];
        if (override is String && override.isNotEmpty) {
          cache[i] = cache[i].copyWith(imageUrl: override);
          if (rawCache != null && i < rawCache.length) {
            rawCache[i]['imageUrl'] = override;
          }
        }
      }
    } catch (e) {
      debugPrint('[MealCatalog] image overrides skipped: $e');
    }
  }

  static Map<String, dynamic> _normalizeMealMap(Map<String, dynamic> meal) {
    final normalized = Map<String, dynamic>.from(meal);
    normalized['id'] = meal['id']?.toString() ?? '';
    normalized['name'] = meal['name']?.toString() ?? '';
    normalized['description'] = meal['description']?.toString() ?? '';
    normalized['calories'] = (meal['calories'] as num?)?.toDouble() ?? 0.0;
    normalized['protein'] = (meal['protein'] as num?)?.toDouble() ?? 0.0;
    normalized['carbs'] = (meal['carbs'] as num?)?.toDouble() ?? 0.0;
    normalized['fats'] = (meal['fats'] as num?)?.toDouble() ?? 0.0;
    normalized['glycemicIndex'] = (meal['glycemicIndex'] as num?)?.toInt() ?? 0;
    normalized['mealType'] = meal['mealType']?.toString() ?? 'Lunch';
    normalized['mealRole'] = meal['mealRole']?.toString() ?? 'main';
    normalized['cuisine'] = meal['cuisine']?.toString() ?? 'international';
    normalized['prepTime'] = meal['prepTime']?.toString() ?? '20 min';
    normalized['difficulty'] = meal['difficulty']?.toString() ?? 'easy';
    normalized['flexibilityScore'] =
        (meal['flexibilityScore'] as num?)?.toDouble() ?? 0.0;
    normalized['availability'] = meal['availability']?.toString() ?? 'unknown';
    normalized['dietTags'] = _stringList(meal['dietTags']);
    normalized['suitableFor'] = _stringList(meal['suitableFor']);
    normalized['tags'] = _stringList(meal['tags']);
    normalized['ingredients'] = _normalizeIngredients(meal['ingredients']);
    normalized['steps'] = _stringList(meal['steps']);
    normalized['servings'] = (meal['servings'] as num?)?.toInt() ?? 1;

    final imageUrl = _nonEmptyString(meal['imageUrl']);
    if (imageUrl == null) {
      normalized.remove('imageUrl');
    } else {
      normalized['imageUrl'] = imageUrl;
    }

    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeIngredients(dynamic raw) {
    if (raw is! List) return const [];

    final normalized = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map) {
        normalized.add({
          'name': entry['name']?.toString() ?? '',
          'quantity': entry['quantity'],
          'unit': entry['unit']?.toString() ?? '',
          'substitutes': _stringList(entry['substitutes']),
        });
      } else if (entry is String && entry.trim().isNotEmpty) {
        normalized.add({
          'name': entry.trim(),
          'quantity': null,
          'unit': '',
          'substitutes': const <String>[],
        });
      }
    }
    return normalized;
  }

  static Map<String, dynamic> _cloneMealMap(Map<String, dynamic> meal) {
    return Map<String, dynamic>.from(
      meal.map((key, value) => MapEntry(key, _cloneJsonValue(value))),
    );
  }

  static dynamic _cloneJsonValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map(
          (key, nested) => MapEntry(key.toString(), _cloneJsonValue(nested)),
        ),
      );
    }
    if (value is List) {
      return value.map(_cloneJsonValue).toList(growable: false);
    }
    return value;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String? _nonEmptyString(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  static String _normalizeCuisine(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  static bool _containsIgnoreCase(List<String> list, String needle) {
    final target = needle.toLowerCase();
    for (final value in list) {
      if (value.toLowerCase() == target) return true;
    }
    return false;
  }

  /// Reads a `List<String>`-shaped field from either a typed profile object
  /// or a raw Firestore map. Returns an empty list when the field is missing
  /// or the wrong shape.
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

  /// Reads a string-shaped field from either a typed profile object or a
  /// raw Firestore map. Returns an empty string when the field is missing.
  static String _profileString(dynamic profile, String key) {
    final raw = _readProfileField(profile, key);
    if (raw == null) return '';
    return raw.toString();
  }

  static dynamic _readProfileField(dynamic profile, String key) {
    if (profile == null) return null;
    if (profile is Map) return profile[key];
    try {
      switch (key) {
        case 'allergies':
          return profile.allergies;
        case 'avoidFoods':
          return profile.avoidFoods;
        case 'conditions':
          return profile.conditions;
        case 'dietaryPreference':
          return profile.dietaryPreference;
        case 'cuisinePreferences':
          return profile.cuisinePreferences;
        case 'goals':
          return profile.goals;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
