import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Authentication with clean error handling.
/// Translates Firebase error codes into human-readable messages.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes (null = signed out, User = signed in).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the currently signed-in Firebase user, or null.
  User? get currentUser => _auth.currentUser;

  /// Creates a new account with email and password.
  /// Returns the Firebase [UserCredential] on success.
  /// Throws a [String] error message on failure.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] signUp FirebaseAuthException code=${e.code} message=${e.message}');
      throw _mapErrorCode(e.code, e.message);
    } catch (e, st) {
      debugPrint('[AUTH] signUp unknown error: $e\n$st');
      throw 'Something went wrong. Please try again.';
    }
  }

  /// Signs in an existing user with email and password.
  /// Throws a [String] error message on failure.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] signIn FirebaseAuthException code=${e.code} message=${e.message}');
      throw _mapErrorCode(e.code, e.message);
    } catch (e, st) {
      debugPrint('[AUTH] signIn unknown error: $e\n$st');
      throw 'Something went wrong. Please try again.';
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Maps Firebase Auth error codes to user-friendly messages.
  String _mapErrorCode(String code, [String? message]) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled. Enable it in Firebase Console → Authentication → Sign-in method.';
      case 'configuration-not-found':
      case 'admin-restricted-operation':
        return 'Auth not configured for this project. Enable Email/Password in Firebase Console.';
      default:
        return 'Authentication failed ($code)${message != null ? ': $message' : ''}';
    }
  }
}
