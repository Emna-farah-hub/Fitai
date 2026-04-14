import 'package:flutter/foundation.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';

/// Manages the multi-step onboarding flow state.
/// Collects user data step by step and saves the complete profile on completion.
class OnboardingProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  // Current step index (0–11)
  int _currentStep = 0;

  // Collected onboarding data
  String _name = '';
  DateTime _birthday = DateTime(1998, 1, 1);
  double _heightCm = 170.0;
  double _weightKg = 70.0;
  String _sex = 'male';
  String _activityLevel = 'Moderately Active';
  String _fitnessLevel = 'Just starting out';
  final List<String> _conditions = [];
  final List<String> _goals = [];
  String _dietaryPreference = 'Classic';

  bool _isSaving = false;
  String? _errorMessage;

  OnboardingProvider({required UserRepository userRepository})
      : _userRepository = userRepository;

  // Getters
  int get currentStep => _currentStep;
  int get totalSteps => 12;
  String get name => _name;
  DateTime get birthday => _birthday;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;
  String get sex => _sex;
  String get activityLevel => _activityLevel;
  String get fitnessLevel => _fitnessLevel;
  List<String> get conditions => List.unmodifiable(_conditions);
  List<String> get goals => List.unmodifiable(_goals);
  String get dietaryPreference => _dietaryPreference;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  double get progress => (_currentStep + 1) / totalSteps;

  // Setters that auto-notify
  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setBirthday(DateTime value) {
    _birthday = value;
    notifyListeners();
  }

  void setHeight(double cm) {
    _heightCm = cm;
    notifyListeners();
  }

  void setWeight(double kg) {
    _weightKg = kg;
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

  /// Resets all onboarding state for a fresh start.
  void reset() {
    _currentStep = 0;
    _name = '';
    _birthday = DateTime(1998, 1, 1);
    _heightCm = 170.0;
    _weightKg = 70.0;
    _sex = 'male';
    _activityLevel = 'Moderately Active';
    _fitnessLevel = 'Just starting out';
    _conditions.clear();
    _goals.clear();
    _dietaryPreference = 'Classic';
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
      final bmr = NutritionCalculator.calculateBMR(
        weight: _weightKg,
        height: _heightCm,
        age: age,
        sex: _sex,
      );
      final tdee = NutritionCalculator.calculateTDEE(
        bmr: bmr,
        activityLevel: _activityLevel,
      );
      final dailyCalorieGoal = NutritionCalculator.calculateDailyCalorieGoal(
        tdee: tdee,
        goals: _goals.isEmpty ? ['Maintain Weight'] : _goals,
      );

      final profile = UserProfile(
        uid: uid,
        name: _name,
        birthday: birthdayIso,
        age: age,
        height: _heightCm,
        weight: _weightKg,
        sex: _sex,
        activityLevel: _activityLevel,
        fitnessLevel: _fitnessLevel,
        conditions: _conditions.isEmpty ? ['None'] : List.from(_conditions),
        goals: _goals.isEmpty ? ['Maintain Weight'] : List.from(_goals),
        dietaryPreference: _dietaryPreference,
        bmr: bmr,
        tdee: tdee,
        dailyCalorieGoal: dailyCalorieGoal,
        onboardingComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _userRepository.saveProfile(profile);
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
