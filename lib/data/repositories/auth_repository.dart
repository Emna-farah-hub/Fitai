import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';

/// Coordinates authentication and initial profile creation.
/// Acts as the single entry point for auth operations in the business logic layer.
class AuthRepository {
  final FirebaseAuthService _authService;
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

  /// Signs up a new user and creates an empty Firestore profile.
  /// Returns the new Firebase user's uid on success.
  Future<String> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signUpWithEmail(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    // Create a blank profile document so the user exists in Firestore
    final emptyProfile = UserProfile.empty(uid);
    await _firestoreService.saveUserProfile(emptyProfile);
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
