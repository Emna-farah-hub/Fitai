/// Unified meal model used by the swipe flow, catalog, and personalization
/// services. Reads directly from the production_meals_v2.json schema.
class Meal {
  final String id;
  final String name;
  final String description;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final int? glycemicIndex;
  final String mealType;
  final String? mealRole;
  final String cuisine;
  final String prepTime;
  final String difficulty;
  final double? flexibilityScore;
  final List<String> dietTags;
  final List<String> suitableFor;
  final List<String> tags;
  final List<String> ingredients;
  final List<String>? steps;
  final int? servings;

  /// Remote photo URL for this meal. Optional — when null the card falls
  /// back to the cuisine-level asset, and finally to an icon gradient.
  final String? imageUrl;

  const Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.glycemicIndex,
    required this.mealType,
    required this.mealRole,
    required this.cuisine,
    required this.prepTime,
    required this.difficulty,
    required this.flexibilityScore,
    required this.dietTags,
    required this.suitableFor,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.servings,
    this.imageUrl,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0,
      glycemicIndex: (json['glycemicIndex'] as num?)?.toInt(),
      mealType: json['mealType']?.toString() ?? 'Lunch',
      mealRole: json['mealRole']?.toString(),
      cuisine: json['cuisine']?.toString() ?? 'international',
      prepTime: json['prepTime']?.toString() ?? '20 min',
      difficulty: json['difficulty']?.toString() ?? 'easy',
      flexibilityScore: (json['flexibilityScore'] as num?)?.toDouble(),
      dietTags: _stringList(json['dietTags']),
      suitableFor: _stringList(json['suitableFor']),
      tags: _stringList(json['tags']),
      ingredients: _ingredientNames(json['ingredients']),
      steps: _optionalStringList(json['steps']),
      servings: (json['servings'] as num?)?.toInt(),
      imageUrl: _nonEmptyString(json['imageUrl']),
    );
  }

  String get imageAssetPath => 'assets/images/cuisine/$cuisine.jpg';

  bool get hasNetworkImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Returns a copy of this meal with a different remote photo URL. Used by
  /// the catalog when applying Firestore-side image overrides on top of the
  /// bundled JSON. Pass null (the default) to keep the existing value.
  Meal copyWith({String? imageUrl}) {
    return Meal(
      id: id,
      name: name,
      description: description,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      glycemicIndex: glycemicIndex,
      mealType: mealType,
      mealRole: mealRole,
      cuisine: cuisine,
      prepTime: prepTime,
      difficulty: difficulty,
      flexibilityScore: flexibilityScore,
      dietTags: dietTags,
      suitableFor: suitableFor,
      tags: tags,
      ingredients: ingredients,
      steps: steps,
      servings: servings,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Returns a map shaped for the swipe card widget. The card reads its
  /// fields off this map so the catalog layer can stay decoupled from the
  /// widget's display contract.
  Map<String, dynamic> toSwipeCardMap() {
    final useNetwork = hasNetworkImage;
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageSource': useNetwork ? 'network' : 'local',
      'imagePath': useNetwork ? imageUrl! : imageAssetPath,
      'isLocalImage': !useNetwork,
      'cuisineAssetPath': imageAssetPath,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'glycemicIndex': glycemicIndex ?? 0,
      'mealType': mealType,
      'cuisine': cuisine,
      'prepTime': prepTime,
      'difficulty': difficulty,
      'tags': tags,
      'mainIngredients': ingredients,
    };
  }

  static String? _nonEmptyString(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static List<String>? _optionalStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return null;
  }

  static List<String> _ingredientNames(dynamic raw) {
    if (raw is! List) return const [];
    final names = <String>[];
    for (final entry in raw) {
      if (entry is Map) {
        final name = entry['name']?.toString();
        if (name != null && name.isNotEmpty) names.add(name);
      } else if (entry is String && entry.isNotEmpty) {
        names.add(entry);
      }
    }
    return names;
  }
}
