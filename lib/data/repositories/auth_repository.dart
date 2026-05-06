import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';

/// Coordinates authentication and initial profile creation.
/// Acts as the single entry point for auth operations in the business logic layer.
class AuthRepository {
  final FirebaseAuthService _authService;
  // Kept for symmetry / future use (e.g. profile bootstrap on signup).
  // ignore: unused_field
  final FirestoreService _firestoreService;

  AuthRepository({
    required FirebaseAuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService;

  /// Auth state stream — emits null when signed out.
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// Currently authenticated Firebase user.
  User? get currentUser => _authService.currentUser;

  /// Signs up a new user. Returns the new Firebase user's uid.
  ///
  /// The Firestore profile document is intentionally NOT created here:
  /// it is written at the end of onboarding with the real values. Creating
  /// an empty doc here previously caused "Failed to save profile" errors
  /// when Firestore rules / network rejected the write while the Auth user
  /// had already been created — leaving the user unable to retry.
  Future<String> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signUpWithEmail(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    debugPrint('[AUTH] signUp success uid=$uid email=$email');
    return uid;
  }

  /// Signs in an existing user.
  /// Returns the Firebase user's uid on success.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signInWithEmail(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
