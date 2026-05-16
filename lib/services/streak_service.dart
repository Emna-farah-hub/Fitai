import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Maintains the user's consecutive-day meal-logging streak.
///
/// Data shape (`users/{uid}`):
///   - `streakDays:    int`     — current consecutive days with ≥1 meal logged
///   - `longestStreak: int`     — best streak ever
///   - `lastLogDate:   String`  — yyyy-MM-dd of the most recent meal log
///
/// Increment rules (atomic via Firestore transaction):
///   - lastLogDate == today          → no change (already counted today)
///   - lastLogDate == yesterday      → streakDays += 1
///   - lastLogDate older or absent   → streakDays = 1 (streak resets)
///
/// longestStreak is updated to `max(longestStreak, streakDays)` on every write.
class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _todayKey([DateTime? now]) =>
      DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());

  static String _yesterdayKey([DateTime? now]) =>
      DateFormat('yyyy-MM-dd')
          .format((now ?? DateTime.now()).subtract(const Duration(days: 1)));

  /// Called from `MealJournalService.addMeal` after every successful log.
  /// Safe to call multiple times per day — it's idempotent.
  Future<void> recordMealLog(String uid) async {
    if (uid.isEmpty) return;
    final docRef = _db.collection('users').doc(uid);
    final today = _todayKey();
    final yesterday = _yesterdayKey();

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;

        final data = snap.data() ?? {};
        final lastLogDate = (data['lastLogDate'] as String?) ?? '';
        final currentStreak = (data['streakDays'] as num?)?.toInt() ?? 0;
        final longest = (data['longestStreak'] as num?)?.toInt() ?? 0;

        if (lastLogDate == today) {
          // Already logged today — nothing to update.
          return;
        }

        final newStreak = (lastLogDate == yesterday) ? currentStreak + 1 : 1;
        final newLongest = newStreak > longest ? newStreak : longest;

        tx.update(docRef, {
          'streakDays': newStreak,
          'longestStreak': newLongest,
          'lastLogDate': today,
        });
      });
    } catch (e) {
      debugPrint('[STREAK] recordMealLog failed: $e');
    }
  }

  /// Real-time stream of the user's current streak. Emits 0 when the
  /// profile document does not exist or the field is missing.
  Stream<int> streakStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return 0;
      return (snap.data()?['streakDays'] as num?)?.toInt() ?? 0;
    });
  }

  /// One-shot read of the current streak (e.g. for share previews).
  Future<int> getStreak(String uid) async {
    if (uid.isEmpty) return 0;
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['streakDays'] as num?)?.toInt() ?? 0;
  }
}
