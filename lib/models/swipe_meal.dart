/// Represents a complete meal shown in the swipe discovery screen.
/// Different from FoodItem — this is a full dish, not an ingredient.
class SwipeMeal {
  final String id;
  final String name;
  final String description;
  final String imageSource; // "local" or "network"
  final String imagePath;   // asset path or URL
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final int glycemicIndex;
  final String mealType;
  final String cuisine;
  final String prepTime;
  final String difficulty;
  final List<String> tags;
  final List<String> mainIngredients;

  const SwipeMeal({
    required this.id,
    required this.name,
    required this.description,
    required this.imageSource,
    required this.imagePath,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.glycemicIndex,
    required this.mealType,
    required this.cuisine,
    required this.prepTime,
    required this.difficulty,
    required this.tags,
    required this.mainIngredients,
  });

  factory SwipeMeal.fromMap(Map<String, dynamic> map) {
    return SwipeMeal(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageSource: map['imageSource'] ?? 'network',
      imagePath: map['imagePath'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fats: (map['fats'] ?? 0).toDouble(),
      glycemicIndex: (map['glycemicIndex'] ?? 0).toInt(),
      mealType: map['mealType'] ?? 'Lunch',
      cuisine: map['cuisine'] ?? 'western',
      prepTime: map['prepTime'] ?? '20 min',
      difficulty: map['difficulty'] ?? 'easy',
      tags: List<String>.from(map['tags'] ?? []),
      mainIngredients: List<String>.from(map['mainIngredients'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'imageSource': imageSource,
        'imagePath': imagePath,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'glycemicIndex': glycemicIndex,
        'mealType': mealType,
        'cuisine': cuisine,
        'prepTime': prepTime,
        'difficulty': difficulty,
        'tags': tags,
        'mainIngredients': mainIngredients,
      };

  bool get isLocalImage => imageSource == 'local';
}
