/// Nutrition calculation utilities for FitAI.
/// Implements Mifflin-St Jeor equation for BMR,
/// and Harris-Benedict multipliers for TDEE.
class NutritionCalculator {
  NutritionCalculator._();

  // Activity level TDEE multipliers
  static const Map<String, double> _activityMultipliers = {
    'Sedentary': 1.2,
    'Lightly Active': 1.375,
    'Moderately Active': 1.55,
    'Very Active': 1.725,
  };

  /// Calculates Basal Metabolic Rate using Mifflin-St Jeor equation.
  /// [weight] in kg, [height] in cm, [age] in years, [sex] is 'male' or 'female'.
  static double calculateBMR({
    required double weight,
    required double height,
    required int age,
    required String sex,
  }) {
    // Base formula: 10 * weight + 6.25 * height - 5 * age
    final base = (10 * weight) + (6.25 * height) - (5 * age);
    // +5 for male, -161 for female
    return sex.toLowerCase() == 'male' ? base + 5 : base - 161;
  }

  /// Calculates Total Daily Energy Expenditure.
  /// TDEE = BMR × activity multiplier
  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    final multiplier = _activityMultipliers[activityLevel] ?? 1.2;
    return bmr * multiplier;
  }

  /// Determines daily calorie goal based on user goals.
  /// Lose weight: TDEE - 400
  /// Build muscle / gain: TDEE + 300
  /// Maintain / other: TDEE
  static int calculateDailyCalorieGoal({
    required double tdee,
    required List<String> goals,
  }) {
    final lowerGoals = goals.map((g) => g.toLowerCase()).toList();
    if (lowerGoals.any((g) => g.contains('lose'))) {
      return (tdee - 400).round();
    } else if (lowerGoals.any((g) => g.contains('muscle') || g.contains('build'))) {
      return (tdee + 300).round();
    }
    return tdee.round();
  }

  /// Calculates age from a birthdate string (ISO format: yyyy-MM-dd).
  static int calculateAge(String birthdayIso) {
    try {
      final birthday = DateTime.parse(birthdayIso);
      final now = DateTime.now();
      int age = now.year - birthday.year;
      if (now.month < birthday.month ||
          (now.month == birthday.month && now.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 25; // fallback
    }
  }

  /// Converts height from inches to centimeters.
  static double inchesToCm(double inches) => inches * 2.54;

  /// Converts height from centimeters to inches.
  static double cmToInches(double cm) => cm / 2.54;

  /// Converts weight from pounds to kilograms.
  static double lbsToKg(double lbs) => lbs * 0.453592;

  /// Converts weight from kilograms to pounds.
  static double kgToLbs(double kg) => kg / 0.453592;
}
