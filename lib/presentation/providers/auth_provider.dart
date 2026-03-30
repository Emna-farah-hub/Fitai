import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/auth_repository.dart';

/// Manages authentication state for the entire app.
/// Exposed via Provider so any widget can react to sign-in / sign-out.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _authRepository.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes from Firebase.
  Stream<User?> get authStateChanges => _authRepository.authStateChanges;

  /// Registers a new user. Returns true on success.
  Future<bool> signUp({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authRepository.signUp(email: email, password: password);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs in an existing user. Returns true on success.
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authRepository.signIn(email: email, password: password);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _authRepository.signOut();
    notifyListeners();
  }

  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
