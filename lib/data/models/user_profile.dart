import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the complete profile of a FitAI user.
/// Stored in Firestore under users/{uid}.
class UserProfile {
  final String uid;
  final String name;
  final String primaryGoal;
  final String motivation;
  final String referralSource;
  final String birthday; // ISO date string e.g. "1998-05-14"
  final int age;
  final double height; // always stored in cm
  final double heightCm; // explicit onboarding field
  final double weight; // always stored in kg
  final double weightKg; // explicit onboarding field
  final double targetWeightKg;
  final String sex; // 'male' or 'female'
  final String gender;
  final String activityLevel;
  final String fitnessLevel;
  final String nutritionExperience;
  final List<String> struggles;
  final String pace;
  final List<String> mealFrequency;
  final List<String> conditions;
  final List<String> goals;
  final String dietaryPreference;
  final String dietType;
  final List<String> allergies;
  final List<String> cuisinePreferences;
  final String cookingSkill;
  final String cookingTime;
  final List<String> avoidFoods;
  final double bmr;
  final double tdee;
  final int dailyCalorieGoal;
  final int proteinGrams;
  final int fatGrams;
  final int carbGrams;
  final bool onboardingComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.name,
    this.primaryGoal = '',
    this.motivation = '',
    this.referralSource = '',
    required this.birthday,
    required this.age,
    required this.height,
    double? heightCm,
    required this.weight,
    double? weightKg,
    this.targetWeightKg = 0,
    required this.sex,
    String? gender,
    required this.activityLevel,
    required this.fitnessLevel,
    this.nutritionExperience = '',
    this.struggles = const [],
    this.pace = 'moderate',
    this.mealFrequency = const [],
    required this.conditions,
    required this.goals,
    required this.dietaryPreference,
    String? dietType,
    this.allergies = const [],
    this.cuisinePreferences = const [],
    this.cookingSkill = '',
    this.cookingTime = '',
    this.avoidFoods = const [],
    required this.bmr,
    required this.tdee,
    required this.dailyCalorieGoal,
    this.proteinGrams = 0,
    this.fatGrams = 0,
    this.carbGrams = 0,
    required this.onboardingComplete,
    required this.createdAt,
    required this.updatedAt,
  }) : heightCm = heightCm ?? height,
       weightKg = weightKg ?? weight,
       gender = gender ?? sex,
       dietType = dietType ?? dietaryPreference;

  /// Creates a UserProfile from a Firestore document snapshot.
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      primaryGoal: data['primaryGoal'] ?? '',
      motivation: data['motivation'] ?? data['goalMotivation'] ?? '',
      referralSource: data['referralSource'] ?? '',
      birthday: data['birthday'] ?? '',
      age: data['age'] ?? 0,
      height: (data['height'] ?? 170.0).toDouble(),
      heightCm: (data['heightCm'] ?? data['height'] ?? 170.0).toDouble(),
      weight: (data['weight'] ?? 70.0).toDouble(),
      weightKg: (data['weightKg'] ?? data['weight'] ?? 70.0).toDouble(),
      targetWeightKg: (data['targetWeightKg'] ?? 0.0).toDouble(),
      sex: data['sex'] ?? 'male',
      gender: data['gender'] ?? data['sex'] ?? 'male',
      activityLevel: data['activityLevel'] ?? 'Sedentary',
      fitnessLevel: data['fitnessLevel'] ?? 'Just starting out',
      nutritionExperience: data['nutritionExperience'] ?? '',
      struggles: List<String>.from(data['struggles'] ?? []),
      pace: data['pace'] ?? 'moderate',
      mealFrequency: List<String>.from(data['mealFrequency'] ?? []),
      conditions: List<String>.from(data['conditions'] ?? []),
      goals: List<String>.from(data['goals'] ?? []),
      dietaryPreference: data['dietaryPreference'] ?? 'Classic',
      dietType: data['dietType'] ?? data['dietaryPreference'] ?? 'Classic',
      allergies: List<String>.from(data['allergies'] ?? []),
      cuisinePreferences: List<String>.from(data['cuisinePreferences'] ?? []),
      cookingSkill: data['cookingSkill'] ?? '',
      cookingTime: data['cookingTime'] ?? '',
      avoidFoods: List<String>.from(data['avoidFoods'] ?? []),
      bmr: (data['bmr'] ?? 0.0).toDouble(),
      tdee: (data['tdee'] ?? 0.0).toDouble(),
      dailyCalorieGoal: data['dailyCalorieGoal'] ?? 2000,
      proteinGrams: data['proteinGrams'] ?? 0,
      fatGrams: data['fatGrams'] ?? 0,
      carbGrams: data['carbGrams'] ?? 0,
      onboardingComplete: data['onboardingComplete'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the UserProfile to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'primaryGoal': primaryGoal,
      'motivation': motivation,
      'referralSource': referralSource,
      'birthday': birthday,
      'age': age,
      'height': height,
      'heightCm': heightCm,
      'weight': weight,
      'weightKg': weightKg,
      'targetWeightKg': targetWeightKg,
      'sex': sex,
      'gender': gender,
      'activityLevel': activityLevel,
      'fitnessLevel': fitnessLevel,
      'nutritionExperience': nutritionExperience,
      'struggles': struggles,
      'pace': pace,
      'mealFrequency': mealFrequency,
      'conditions': conditions,
      'goals': goals,
      'dietaryPreference': dietaryPreference,
      'dietType': dietType,
      'allergies': allergies,
      'cuisinePreferences': cuisinePreferences,
      'cookingSkill': cookingSkill,
      'cookingTime': cookingTime,
      'avoidFoods': avoidFoods,
      'bmr': bmr,
      'tdee': tdee,
      'dailyCalorieGoal': dailyCalorieGoal,
      'proteinGrams': proteinGrams,
      'fatGrams': fatGrams,
      'carbGrams': carbGrams,
      'onboardingComplete': onboardingComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a copy of this UserProfile with the given fields replaced.
  UserProfile copyWith({
    String? uid,
    String? name,
    String? primaryGoal,
    String? motivation,
    String? referralSource,
    String? birthday,
    int? age,
    double? height,
    double? heightCm,
    double? weight,
    double? weightKg,
    double? targetWeightKg,
    String? sex,
    String? gender,
    String? activityLevel,
    String? fitnessLevel,
    String? nutritionExperience,
    List<String>? struggles,
    String? pace,
    List<String>? mealFrequency,
    List<String>? conditions,
    List<String>? goals,
    String? dietaryPreference,
    String? dietType,
    List<String>? allergies,
    List<String>? cuisinePreferences,
    String? cookingSkill,
    String? cookingTime,
    List<String>? avoidFoods,
    double? bmr,
    double? tdee,
    int? dailyCalorieGoal,
    int? proteinGrams,
    int? fatGrams,
    int? carbGrams,
    bool? onboardingComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      motivation: motivation ?? this.motivation,
      referralSource: referralSource ?? this.referralSource,
      birthday: birthday ?? this.birthday,
      age: age ?? this.age,
      height: height ?? this.height,
      heightCm: heightCm ?? this.heightCm,
      weight: weight ?? this.weight,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      sex: sex ?? this.sex,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      nutritionExperience: nutritionExperience ?? this.nutritionExperience,
      struggles: struggles ?? this.struggles,
      pace: pace ?? this.pace,
      mealFrequency: mealFrequency ?? this.mealFrequency,
      conditions: conditions ?? this.conditions,
      goals: goals ?? this.goals,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      dietType: dietType ?? this.dietType,
      allergies: allergies ?? this.allergies,
      cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
      cookingSkill: cookingSkill ?? this.cookingSkill,
      cookingTime: cookingTime ?? this.cookingTime,
      avoidFoods: avoidFoods ?? this.avoidFoods,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      carbGrams: carbGrams ?? this.carbGrams,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a blank profile for a given uid (used before onboarding is complete).
  factory UserProfile.empty(String uid) {
    return UserProfile(
      uid: uid,
      name: '',
      primaryGoal: '',
      motivation: '',
      referralSource: '',
      birthday: '',
      age: 0,
      height: 170.0,
      heightCm: 170.0,
      weight: 70.0,
      weightKg: 70.0,
      targetWeightKg: 65.0,
      sex: 'male',
      gender: 'male',
      activityLevel: 'Sedentary',
      fitnessLevel: 'Just starting out',
      nutritionExperience: '',
      struggles: const [],
      pace: 'moderate',
      mealFrequency: const [],
      conditions: const [],
      goals: const [],
      dietaryPreference: 'Classic',
      dietType: 'Classic',
      allergies: const [],
      cuisinePreferences: const [],
      cookingSkill: '',
      cookingTime: '',
      avoidFoods: const [],
      bmr: 0.0,
      tdee: 0.0,
      dailyCalorieGoal: 2000,
      proteinGrams: 0,
      fatGrams: 0,
      carbGrams: 0,
      onboardingComplete: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
