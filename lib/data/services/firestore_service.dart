import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// Handles all Firestore read/write operations for FitAI.
/// All operations include error handling and return typed results.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reference to the users collection.
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  /// Saves or updates the full user profile in Firestore.
  /// Uses set with merge:true so partial updates don't wipe existing data.
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _usersRef.doc(profile.uid).set(
        profile.toFirestore(),
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw 'Failed to save profile: ${e.message}';
    } catch (e) {
      throw 'Unexpected error saving profile.';
    }
  }

  /// Loads a user profile from Firestore by uid.
  /// Returns null if the document does not exist yet.
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw 'Failed to load profile: ${e.message}';
    } catch (e) {
      throw 'Unexpected error loading profile.';
    }
  }

  /// Updates specific fields in a user profile without overwriting the whole doc.
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _usersRef.doc(uid).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to update profile: ${e.message}';
    } catch (e) {
      throw 'Unexpected error updating profile.';
    }
  }

  /// Marks onboarding as complete for the given user.
  Future<void> markOnboardingComplete(String uid) async {
    await updateUserFields(uid, {'onboardingComplete': true});
  }

  /// Returns a real-time stream of a user's profile document.
  Stream<UserProfile?> userProfileStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }
}
