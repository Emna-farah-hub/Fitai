import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the complete profile of a FitAI user.
/// Stored in Firestore under users/{uid}.
class UserProfile {
  final String uid;
  final String name;
  final String birthday; // ISO date string e.g. "1998-05-14"
  final int age;
  final double height; // always stored in cm
  final double weight; // always stored in kg
  final String sex; // 'male' or 'female'
  final String activityLevel;
  final String fitnessLevel;
  final List<String> conditions;
  final List<String> goals;
  final String dietaryPreference;
  final double bmr;
  final double tdee;
  final int dailyCalorieGoal;
  final bool onboardingComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.birthday,
    required this.age,
    required this.height,
    required this.weight,
    required this.sex,
    required this.activityLevel,
    required this.fitnessLevel,
    required this.conditions,
    required this.goals,
    required this.dietaryPreference,
    required this.bmr,
    required this.tdee,
    required this.dailyCalorieGoal,
    required this.onboardingComplete,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a UserProfile from a Firestore document snapshot.
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      birthday: data['birthday'] ?? '',
      age: data['age'] ?? 0,
      height: (data['height'] ?? 170.0).toDouble(),
      weight: (data['weight'] ?? 70.0).toDouble(),
      sex: data['sex'] ?? 'male',
      activityLevel: data['activityLevel'] ?? 'Sedentary',
      fitnessLevel: data['fitnessLevel'] ?? 'Just starting out',
      conditions: List<String>.from(data['conditions'] ?? []),
      goals: List<String>.from(data['goals'] ?? []),
      dietaryPreference: data['dietaryPreference'] ?? 'Classic',
      bmr: (data['bmr'] ?? 0.0).toDouble(),
      tdee: (data['tdee'] ?? 0.0).toDouble(),
      dailyCalorieGoal: data['dailyCalorieGoal'] ?? 2000,
      onboardingComplete: data['onboardingComplete'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the UserProfile to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'birthday': birthday,
      'age': age,
      'height': height,
      'weight': weight,
      'sex': sex,
      'activityLevel': activityLevel,
      'fitnessLevel': fitnessLevel,
      'conditions': conditions,
      'goals': goals,
      'dietaryPreference': dietaryPreference,
      'bmr': bmr,
      'tdee': tdee,
      'dailyCalorieGoal': dailyCalorieGoal,
      'onboardingComplete': onboardingComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a copy of this UserProfile with the given fields replaced.
  UserProfile copyWith({
    String? uid,
    String? name,
    String? birthday,
    int? age,
    double? height,
    double? weight,
    String? sex,
    String? activityLevel,
    String? fitnessLevel,
    List<String>? conditions,
    List<String>? goals,
    String? dietaryPreference,
    double? bmr,
    double? tdee,
    int? dailyCalorieGoal,
    bool? onboardingComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      conditions: conditions ?? this.conditions,
      goals: goals ?? this.goals,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
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
      birthday: '',
      age: 0,
      height: 170.0,
      weight: 70.0,
      sex: 'male',
      activityLevel: 'Sedentary',
      fitnessLevel: 'Just starting out',
      conditions: const [],
      goals: const [],
      dietaryPreference: 'Classic',
      bmr: 0.0,
      tdee: 0.0,
      dailyCalorieGoal: 2000,
      onboardingComplete: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
