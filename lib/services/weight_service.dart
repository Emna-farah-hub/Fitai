import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// One weight log entry — typed wrapper around Firestore data.
class WeightEntry {
  final String date; // yyyy-MM-dd
  final double weightKg;
  final DateTime recordedAt;

  const WeightEntry({
    required this.date,
    required this.weightKg,
    required this.recordedAt,
  });

  factory WeightEntry.fromMap(Map<String, dynamic> data) {
    final ts = data['recordedAt'];
    return WeightEntry(
      date: (data['date'] as String?) ?? '',
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      recordedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

/// Manages weight log entries.
///
/// Storage:
///   - `weight_logs/{uid}/entries/{yyyy-MM-dd}` — one entry per day (idempotent)
///   - `users/{uid}.weight`           — mirror of the most recent value
///   - `users/{uid}.lastWeighIn`      — yyyy-MM-dd of the latest log
///
/// Using a date-keyed doc means overwriting today's entry (e.g. re-weighing
/// later) is safe and never duplicates the X-axis on the trend chart.
class WeightService {
  static final WeightService _instance = WeightService._internal();
  factory WeightService() => _instance;
  WeightService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Logs a weight value for today (or a specific date).
  /// Throws on failure so the calling UI can show an error.
  Future<void> logWeight({
    required String uid,
    required double weightKg,
    DateTime? date,
  }) async {
    if (uid.isEmpty) throw ArgumentError('uid required');
    if (weightKg <= 0) throw ArgumentError('weight must be > 0');

    final at = date ?? DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(at);

    final batch = _db.batch();
    batch.set(
      _db
          .collection('weight_logs')
          .doc(uid)
          .collection('entries')
          .doc(dateKey),
      {
        'date': dateKey,
        'weightKg': weightKg,
        'recordedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _db.collection('users').doc(uid),
      {
        'weight': weightKg,
        'weightKg': weightKg,
        'lastWeighIn': dateKey,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Real-time stream of the most recent N entries, oldest first.
  /// Used by the trend chart.
  Stream<List<WeightEntry>> weightHistoryStream(
    String uid, {
    int limit = 12,
  }) {
    if (uid.isEmpty) return Stream.value(const []);
    return _db
        .collection('weight_logs')
        .doc(uid)
        .collection('entries')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final entries = snap.docs
          .map((d) => WeightEntry.fromMap(d.data()))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return entries;
    });
  }

  /// Returns the number of days since the last weigh-in, or null if never.
  /// The dashboard uses this to surface a weekly prompt when value >= 7.
  Future<int?> daysSinceLastWeighIn(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final last = doc.data()?['lastWeighIn'] as String?;
      if (last == null || last.isEmpty) return null;
      final lastDate = DateTime.tryParse(last);
      if (lastDate == null) return null;
      return DateTime.now().difference(lastDate).inDays;
    } catch (e) {
      debugPrint('[WEIGHT] daysSinceLastWeighIn failed: $e');
      return null;
    }
  }
}
