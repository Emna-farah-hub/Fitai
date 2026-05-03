class FoodItem {
  final String id;
  final String name;
  final double caloriesPer100g;
  final double protein;
  final double carbs;
  final double fats;
  final int glycemicIndex;
  final bool isTunisian;
  final String source;
  final String category;
  final List<String> tags;

  const FoodItem({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.glycemicIndex,
    required this.isTunisian,
    required this.source,
    required this.category,
    this.tags = const [],
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      caloriesPer100g: (map['caloriesPer100g'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fats: (map['fats'] ?? 0).toDouble(),
      glycemicIndex: (map['glycemicIndex'] ?? 0).toInt(),
      isTunisian: map['isTunisian'] ?? false,
      source: map['source'] ?? 'local',
      category: map['category'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'caloriesPer100g': caloriesPer100g,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    'glycemicIndex': glycemicIndex,
    'isTunisian': isTunisian,
    'source': source,
    'category': category,
    'tags': tags,
  };
}
