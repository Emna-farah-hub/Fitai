import '../models/user_profile.dart';
import '../services/firestore_service.dart';

/// Handles all CRUD operations for the UserProfile entity.
/// Wraps FirestoreService with higher-level profile logic.
class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  /// Saves the complete user profile to Firestore.
  Future<void> saveProfile(UserProfile profile) async {
    await _firestoreService.saveUserProfile(profile);
  }

  /// Loads the user profile. Returns null if not yet created.
  Future<UserProfile?> getProfile(String uid) async {
    return await _firestoreService.getUserProfile(uid);
  }

  /// Updates a subset of profile fields (e.g., after editing preferences).
  Future<void> updateFields(String uid, Map<String, dynamic> fields) async {
    await _firestoreService.updateUserFields(uid, fields);
  }

  /// Marks the user's onboarding as complete in Firestore.
  Future<void> completeOnboarding(String uid) async {
    await _firestoreService.markOnboardingComplete(uid);
  }

  /// Real-time stream of the user's profile — useful for reactive UI.
  Stream<UserProfile?> profileStream(String uid) {
    return _firestoreService.userProfileStream(uid);
  }
}
