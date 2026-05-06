import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Handles all Firestore read/write operations for FitAI.
/// All operations include error handling and return typed results.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reference to the users collection.
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  String _friendly(String op, FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied while $op. Check Firestore rules in Firebase Console.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network unavailable while $op. Check your internet connection.';
      case 'not-found':
        return 'Firestore database not found. Create it in Firebase Console → Firestore Database.';
      case 'unauthenticated':
        return 'You must be signed in to $op.';
      default:
        return 'Failed $op (${e.code}): ${e.message ?? "unknown"}';
    }
  }

  /// Saves or updates the full user profile in Firestore.
  /// Uses set with merge:true so partial updates don't wipe existing data.
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _usersRef.doc(profile.uid).set(
        profile.toFirestore(),
        SetOptions(merge: true),
      );
      debugPrint('[FIRESTORE] saveUserProfile OK uid=${profile.uid}');
    } on FirebaseException catch (e) {
      debugPrint('[FIRESTORE] saveUserProfile FAILED code=${e.code} message=${e.message}');
      throw _friendly('saving profile', e);
    } catch (e, st) {
      debugPrint('[FIRESTORE] saveUserProfile unknown error: $e\n$st');
      throw 'Unexpected error saving profile: $e';
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
      debugPrint('[FIRESTORE] getUserProfile FAILED code=${e.code} message=${e.message}');
      throw _friendly('loading profile', e);
    } catch (e, st) {
      debugPrint('[FIRESTORE] getUserProfile unknown error: $e\n$st');
      throw 'Unexpected error loading profile: $e';
    }
  }

  /// Updates specific fields in a user profile without overwriting the whole doc.
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _usersRef.doc(uid).set({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('[FIRESTORE] updateUserFields FAILED code=${e.code} message=${e.message}');
      throw _friendly('updating profile', e);
    } catch (e, st) {
      debugPrint('[FIRESTORE] updateUserFields unknown error: $e\n$st');
      throw 'Unexpected error updating profile: $e';
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
