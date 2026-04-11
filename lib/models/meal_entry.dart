class MealEntry {
  final String id;
  final String userId;
  final String date;
  final String foodName;
  final double quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final int glycemicIndex;
  final String mealType;
  final String inputMethod;
  final DateTime timestamp;

  const MealEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.foodName,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.glycemicIndex,
    required this.mealType,
    required this.inputMethod,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'date': date,
    'foodName': foodName,
    'quantity': quantity,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    'glycemicIndex': glycemicIndex,
    'mealType': mealType,
    'inputMethod': inputMethod,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MealEntry.fromMap(Map<String, dynamic> map) => MealEntry(
    id: map['id'] ?? '',
    userId: map['userId'] ?? '',
    date: map['date'] ?? '',
    foodName: map['foodName'] ?? '',
    quantity: (map['quantity'] ?? 0).toDouble(),
    calories: (map['calories'] ?? 0).toDouble(),
    protein: (map['protein'] ?? 0).toDouble(),
    carbs: (map['carbs'] ?? 0).toDouble(),
    fats: (map['fats'] ?? 0).toDouble(),
    glycemicIndex: (map['glycemicIndex'] ?? 0).toInt(),
    mealType: map['mealType'] ?? 'Lunch',
    inputMethod: map['inputMethod'] ?? 'manual',
    timestamp: DateTime.parse(map['timestamp']),
  );
}
