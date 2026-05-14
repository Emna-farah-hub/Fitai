import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';

/// Manages the multi-step onboarding flow state.
/// Collects user data step by step and saves the complete profile on completion.
class OnboardingProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  static DateTime _birthdayForAge(int age) {
    final now = DateTime.now();
    return DateTime(now.year - age, now.month, now.day);
  }

  // Current step index (0–11)
  int _currentStep = 0;

  // Collected onboarding data
  String _name = '';
  int _age = 25;
  DateTime _birthday = _birthdayForAge(25);
  double _heightCm = 170.0;
  double _weightKg = 70.0;
  double _targetWeightKg = 65.0;
  String _sex = 'male';
  String _activityLevel = 'Moderately Active';
  String _fitnessLevel = 'Just starting out';
  String _nutritionExperience = "I'm a beginner";
  String _pace = 'moderate';
  final List<String> _conditions = [];
  final List<String> _goals = [];
  final List<String> _struggles = [];
  final List<String> _mealFrequency = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
  ];
  String _dietaryPreference = 'I eat everything';
  final List<String> _dietaryRestrictions = [];
  final List<String> _favoriteCuisines = [];
  String? _cookingSkill;
  String? _cookingTime;
  final List<String> _avoidFoods = [];
  String? _primaryGoal;
  String? _goalMotivation;
  String? _referralSource;
  double _bmr = 0;
  double _tdee = 0;
  int _dailyCalorieGoal = 0;
  int _proteinGrams = 0;
  int _fatGrams = 0;
  int _carbGrams = 0;

  bool _isSaving = false;
  String? _errorMessage;

  OnboardingProvider({required UserRepository userRepository})
    : _userRepository = userRepository;

  // Getters
  int get currentStep => _currentStep;
  int get totalSteps => 12;
  // Steps shown in the progress bar (excludes the final personalizing screen
  // which has its own full-screen UI).
  int get progressBarSteps => totalSteps - 1;
  String get name => _name;
  int get age => _age;
  DateTime get birthday => _birthday;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;
  double get targetWeightKg => _targetWeightKg;
  String get sex => _sex;
  String get activityLevel => _activityLevel;
  String get fitnessLevel => _fitnessLevel;
  String get nutritionExperience => _nutritionExperience;
  String get pace => _pace;
  String get resultPace => _pace;
  String get resultPaceLabel => _labelForPace(_pace);
  List<String> get conditions => List.unmodifiable(_conditions);
  List<String> get goals => List.unmodifiable(_goals);
  List<String> get struggles => List.unmodifiable(_struggles);
  List<String> get mealFrequency => List.unmodifiable(_mealFrequency);
  String get dietaryPreference => _dietaryPreference;
  List<String> get dietaryRestrictions =>
      List.unmodifiable(_dietaryRestrictions);
  List<String> get favoriteCuisines => List.unmodifiable(_favoriteCuisines);
  String? get cookingSkill => _cookingSkill;
  String? get cookingTime => _cookingTime;
  List<String> get avoidFoods => List.unmodifiable(_avoidFoods);
  String? get primaryGoal => _primaryGoal;
  String? get goalMotivation => _goalMotivation;
  String? get motivation => _goalMotivation;
  String get gender => _sex;
  String get dietType => _dietaryPreference;
  List<String> get allergies => List.unmodifiable(_dietaryRestrictions);
  List<String> get cuisinePreferences => List.unmodifiable(_favoriteCuisines);
  String? get referralSource => _referralSource;
  double get bmr => _bmr;
  double get tdee => _tdee;
  int get dailyCalorieGoal => _dailyCalorieGoal;
  int get proteinGrams => _proteinGrams;
  int get fatGrams => _fatGrams;
  int get carbGrams => _carbGrams;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  double get progress => (_currentStep + 1) / totalSteps;

  // Setters that auto-notify
  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setAge(int value) {
    _age = value;
    _birthday = _birthdayForAge(value);
    notifyListeners();
  }

  void setBirthday(DateTime value) {
    _birthday = value;
    _age = NutritionCalculator.calculateAge(
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
    );
    notifyListeners();
  }

  void setHeight(double cm) {
    _heightCm = cm;
    notifyListeners();
  }

  void setWeight(double kg) {
    _weightKg = kg;
    if (_targetWeightKg >= kg) {
      _targetWeightKg = (kg - 5).clamp(40.0, kg).toDouble();
    }
    notifyListeners();
  }

  void setTargetWeight(double kg) {
    _targetWeightKg = kg;
    notifyListeners();
  }

  void setSex(String value) {
    _sex = value;
    notifyListeners();
  }

  void setActivityLevel(String value) {
    _activityLevel = value;
    notifyListeners();
  }

  void setFitnessLevel(String value) {
    _fitnessLevel = value;
    notifyListeners();
  }

  void setNutritionExperience(String value) {
    _nutritionExperience = value;
    notifyListeners();
  }

  static String _normalizePace(String value) => value.toLowerCase();

  static String _labelForPace(String value) {
    final normalized = _normalizePace(value);
    return normalized.isEmpty
        ? 'Moderate'
        : '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  void setResultPace(String value) {
    _pace = _normalizePace(value);
    notifyListeners();
  }

  void toggleStruggle(String value) {
    if (_struggles.contains(value)) {
      _struggles.remove(value);
    } else {
      _struggles.add(value);
    }
    notifyListeners();
  }

  void toggleMealFrequency(String value) {
    if (_mealFrequency.contains(value)) {
      _mealFrequency.remove(value);
    } else {
      _mealFrequency.add(value);
    }
    notifyListeners();
  }

  void toggleCondition(String condition) {
    // "None" clears all other selections
    if (condition == 'None') {
      _conditions.clear();
      _conditions.add('None');
    } else {
      _conditions.remove('None');
      if (_conditions.contains(condition)) {
        _conditions.remove(condition);
      } else {
        _conditions.add(condition);
      }
      if (_conditions.isEmpty) _conditions.add('None');
    }
    notifyListeners();
  }

  void toggleGoal(String goal) {
    if (_goals.contains(goal)) {
      _goals.remove(goal);
    } else {
      _goals.add(goal);
    }
    notifyListeners();
  }

  void setDietaryPreference(String value) {
    _dietaryPreference = value;
    notifyListeners();
  }

  void toggleDietaryRestriction(String value) {
    if (value == 'None') {
      _dietaryRestrictions
        ..clear()
        ..add('None');
    } else {
      _dietaryRestrictions.remove('None');
      if (_dietaryRestrictions.contains(value)) {
        _dietaryRestrictions.remove(value);
      } else {
        _dietaryRestrictions.add(value);
      }
    }
    notifyListeners();
  }

  void toggleFavoriteCuisine(String value) {
    if (_favoriteCuisines.contains(value)) {
      _favoriteCuisines.remove(value);
    } else {
      _favoriteCuisines.add(value);
    }
    notifyListeners();
  }

  void setCookingSkill(String value) {
    _cookingSkill = value;
    notifyListeners();
  }

  void setCookingTime(String value) {
    _cookingTime = value;
    notifyListeners();
  }

  void toggleAvoidFood(String value) {
    if (value == 'None') {
      _avoidFoods
        ..clear()
        ..add('None');
    } else {
      _avoidFoods.remove('None');
      if (_avoidFoods.contains(value)) {
        _avoidFoods.remove(value);
      } else {
        _avoidFoods.add(value);
      }
    }
    notifyListeners();
  }

  void setPrimaryGoal(String value) {
    _primaryGoal = value;
    notifyListeners();
  }

  void setGoalMotivation(String value) {
    _goalMotivation = value;
    notifyListeners();
  }

  void setReferralSource(String value) {
    _referralSource = value;
    notifyListeners();
  }

  void calculatePlan() {
    _bmr = NutritionCalculator.calculateBMR(
      weight: _weightKg,
      height: _heightCm,
      age: _age,
      sex: _sex,
    );
    _tdee = NutritionCalculator.calculateTDEE(
      bmr: _bmr,
      activityLevel: _activityLevel,
    );

    final paceAdjustment = switch (_pace) {
      'gradual' => 300,
      'ambitious' => 750,
      _ => 500,
    };

    _dailyCalorieGoal = (_tdee - paceAdjustment).round().clamp(1200, 5000);

    _proteinGrams = ((_dailyCalorieGoal * 0.30) / 4).round();
    _fatGrams = ((_dailyCalorieGoal * 0.25) / 9).round();
    _carbGrams = ((_dailyCalorieGoal * 0.45) / 4).round();
    notifyListeners();
  }

  Future<void> _setLocalOnboardingComplete(bool value, [String? uid]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', value);
    if (uid != null) {
      await prefs.setBool('onboardingComplete_$uid', value);
    }
  }

  Future<void> completeOnboarding(String uid) async {
    await _userRepository.completeOnboarding(uid);
    await _setLocalOnboardingComplete(true, uid);
  }

  /// Resets all onboarding state for a fresh start.
  void reset() {
    _currentStep = 0;
    _name = '';
    _age = 25;
    _birthday = _birthdayForAge(25);
    _heightCm = 170.0;
    _weightKg = 70.0;
    _targetWeightKg = 65.0;
    _sex = 'male';
    _activityLevel = 'Moderately Active';
    _fitnessLevel = 'Just starting out';
    _nutritionExperience = "I'm a beginner";
    _pace = 'moderate';
    _conditions.clear();
    _goals.clear();
    _struggles.clear();
    _mealFrequency
      ..clear()
      ..addAll(['Breakfast', 'Lunch', 'Dinner', 'Snacks']);
    _dietaryPreference = 'I eat everything';
    _dietaryRestrictions.clear();
    _favoriteCuisines.clear();
    _cookingSkill = null;
    _cookingTime = null;
    _avoidFoods.clear();
    _primaryGoal = null;
    _goalMotivation = null;
    _referralSource = null;
    _bmr = 0;
    _tdee = 0;
    _dailyCalorieGoal = 0;
    _proteinGrams = 0;
    _fatGrams = 0;
    _carbGrams = 0;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Advance to the next onboarding step.
  void nextStep() {
    if (_currentStep < totalSteps - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  /// Go back to the previous step.
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// Builds and saves the complete UserProfile to Firestore.
  /// Calculates BMR, TDEE, and daily calorie goal before saving.
  Future<bool> saveProfile(String uid) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final birthdayIso =
          '${_birthday.year}-${_birthday.month.toString().padLeft(2, '0')}-${_birthday.day.toString().padLeft(2, '0')}';
      final age = NutritionCalculator.calculateAge(birthdayIso);
      _age = age;
      calculatePlan();
      final goalsForProfile = _goals.isEmpty && _primaryGoal != null
          ? [_primaryGoal!]
          : List<String>.from(_goals);

      final profile = UserProfile(
        uid: uid,
        name: _name,
        primaryGoal: _primaryGoal ?? '',
        motivation: _goalMotivation ?? '',
        referralSource: _referralSource ?? '',
        birthday: birthdayIso,
        age: age,
        height: _heightCm,
        heightCm: _heightCm,
        weight: _weightKg,
        weightKg: _weightKg,
        targetWeightKg: _targetWeightKg,
        sex: _sex,
        gender: _sex,
        activityLevel: _activityLevel,
        fitnessLevel: _fitnessLevel,
        nutritionExperience: _nutritionExperience,
        struggles: List.from(_struggles),
        pace: _pace,
        mealFrequency: List.from(_mealFrequency),
        conditions: _conditions.isEmpty ? ['None'] : List.from(_conditions),
        goals: goalsForProfile.isEmpty ? ['Maintain Weight'] : goalsForProfile,
        dietaryPreference: _dietaryPreference,
        dietType: _dietaryPreference,
        allergies: List.from(_dietaryRestrictions),
        cuisinePreferences: List.from(_favoriteCuisines),
        cookingSkill: _cookingSkill ?? '',
        cookingTime: _cookingTime ?? '',
        avoidFoods: List.from(_avoidFoods),
        bmr: _bmr,
        tdee: _tdee,
        dailyCalorieGoal: _dailyCalorieGoal,
        proteinGrams: _proteinGrams,
        fatGrams: _fatGrams,
        carbGrams: _carbGrams,
        onboardingComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _userRepository.saveProfile(profile);
      await _setLocalOnboardingComplete(true, uid);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
