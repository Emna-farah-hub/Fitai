import 'package:flutter/foundation.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';

/// Holds the currently loaded UserProfile and exposes it to the UI.
/// Loaded once on app start after the user is authenticated.
class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProvider({required UserRepository userRepository})
      : _userRepository = userRepository;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;
  bool get onboardingComplete => _profile?.onboardingComplete ?? false;

  /// Loads the user profile from Firestore for the given uid.
  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _userRepository.getProfile(uid);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the in-memory profile (e.g. after onboarding saves to Firestore).
  void setProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  /// Clears the profile when the user signs out.
  void clearProfile() {
    _profile = null;
    notifyListeners();
  }
}
