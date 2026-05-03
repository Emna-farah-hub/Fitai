import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/swipe_meal.dart';

/// Manages per-user tag preference scores for the food recommendation system.
/// Pure Dart — no Gemini calls. All intelligence is math-based.
///
/// Firestore structure:
///   preferences/{uid}
///     ├── tagScores: { "high_protein": 3.2, "tunisian": 5.1, "cold": -2.0, ... }
///     ├── tagUpdatedAt: { "high_protein": Timestamp, "tunisian": Timestamp, ... }
///     ├── likedFoodIds: ["cf001", "cf096", ...]
///     ├── dislikedFoodIds: ["cf071", "cf042", ...]
///     ├── swipeHistory: [ { foodId, liked, timestamp }, ... ]  // last 200
///     ├── totalSwipes: 47
///     └── lastUpdated: Timestamp
class FoodScoringService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── CONSTANTS ────────────────────────────────────────────

  /// How much a single swipe affects each tag score
  static const double _swipeWeight = 1.0;

  /// Decay multiplier applied to scores older than [_decayAfterDays]
  static const double _decayFactor = 0.9;

  /// Number of days before decay kicks in
  static const int _decayAfterDays = 7;

  /// Maximum number of swipe history entries to keep
  static const int _maxSwipeHistory = 200;

  /// Maximum absolute value a tag score can reach (prevents runaway scores)
  static const double _maxScore = 15.0;

  // ─── CORE METHODS ─────────────────────────────────────────

  /// Records a swipe (like or dislike) for a food item.
  /// Updates tag scores, liked/disliked lists, and swipe history.
  Future<void> recordSwipe({
    required String uid,
    required FoodItem food,
    required bool liked,
  }) async {
    final docRef = _db.collection('preferences').doc(uid);
    final doc = await docRef.get();
    final data = doc.exists ? doc.data()! : _emptyPreferences();

    // Get current scores and timestamps
    final tagScores = Map<String, double>.from(
      (data['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
    final tagUpdatedAt = Map<String, Timestamp>.from(
      data['tagUpdatedAt'] as Map<String, dynamic>? ?? {},
    );

    // Update scores for each tag on this food
    final now = Timestamp.now();
    final delta = liked ? _swipeWeight : -_swipeWeight;

    for (final tag in food.tags) {
      final currentScore = tagScores[tag] ?? 0.0;
      // Apply decay to existing score before adding new delta
      final decayedScore = _applyDecay(currentScore, tagUpdatedAt[tag]);
      final newScore = (decayedScore + delta).clamp(-_maxScore, _maxScore);
      tagScores[tag] = newScore;
      tagUpdatedAt[tag] = now;
    }

    // Update liked/disliked food lists
    final likedIds = List<String>.from(data['likedFoodIds'] ?? []);
    final dislikedIds = List<String>.from(data['dislikedFoodIds'] ?? []);

    // Remove from both lists first (in case of re-swipe)
    likedIds.remove(food.id);
    dislikedIds.remove(food.id);

    // Add to appropriate list
    if (liked) {
      likedIds.add(food.id);
    } else {
      dislikedIds.add(food.id);
    }

    // Update swipe history (keep last N entries)
    final history = List<Map<String, dynamic>>.from(data['swipeHistory'] ?? []);
    history.add({
      'foodId': food.id,
      'foodName': food.name,
      'liked': liked,
      'tags': food.tags,
      'timestamp': now,
    });
    // Trim to max size
    while (history.length > _maxSwipeHistory) {
      history.removeAt(0);
    }

    // Save everything
    await docRef.set({
      'tagScores': tagScores,
      'tagUpdatedAt': tagUpdatedAt,
      'likedFoodIds': likedIds,
      'dislikedFoodIds': dislikedIds,
      'swipeHistory': history,
      'totalSwipes': (data['totalSwipes'] ?? 0) + 1,
      'lastUpdated': now,
    });
  }

  /// Records a swipe for a full meal (SwipeMeal). Same tag-scoring logic as
  /// [recordSwipe] but keyed off SwipeMeal's fields instead of FoodItem.
  Future<void> recordMealSwipe({
    required String uid,
    required SwipeMeal meal,
    required bool liked,
  }) async {
    final docRef = _db.collection('preferences').doc(uid);
    final doc = await docRef.get();
    final data = doc.exists ? doc.data()! : _emptyPreferences();

    final tagScores = Map<String, double>.from(
      (data['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
    final tagUpdatedAt = Map<String, Timestamp>.from(
      data['tagUpdatedAt'] as Map<String, dynamic>? ?? {},
    );

    final now = Timestamp.now();
    final delta = liked ? _swipeWeight : -_swipeWeight;

    for (final tag in meal.tags) {
      final currentScore = tagScores[tag] ?? 0.0;
      final decayedScore = _applyDecay(currentScore, tagUpdatedAt[tag]);
      final newScore = (decayedScore + delta).clamp(-_maxScore, _maxScore);
      tagScores[tag] = newScore;
      tagUpdatedAt[tag] = now;
    }

    final likedIds = List<String>.from(data['likedFoodIds'] ?? []);
    final dislikedIds = List<String>.from(data['dislikedFoodIds'] ?? []);
    likedIds.remove(meal.id);
    dislikedIds.remove(meal.id);
    if (liked) {
      likedIds.add(meal.id);
    } else {
      dislikedIds.add(meal.id);
    }

    final history = List<Map<String, dynamic>>.from(data['swipeHistory'] ?? []);
    history.add({
      'foodId': meal.id,
      'foodName': meal.name,
      'liked': liked,
      'tags': meal.tags,
      'timestamp': now,
    });
    while (history.length > _maxSwipeHistory) {
      history.removeAt(0);
    }

    await docRef.set({
      'tagScores': tagScores,
      'tagUpdatedAt': tagUpdatedAt,
      'likedFoodIds': likedIds,
      'dislikedFoodIds': dislikedIds,
      'swipeHistory': history,
      'totalSwipes': (data['totalSwipes'] ?? 0) + 1,
      'lastUpdated': now,
    }, SetOptions(merge: true));
  }

  /// Calculates a preference score for a given food item based on the user's tag scores.
  /// Higher score = better match for user's preferences.
  /// Returns 0.0 if no preferences exist yet.
  Future<double> getScoreForFood({
    required String uid,
    required FoodItem food,
  }) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) return 0.0;
    return _calculateFoodScore(food, scores);
  }

  /// Scores and ranks a list of foods by user preference.
  /// Returns the list sorted from highest to lowest preference score.
  Future<List<ScoredFood>> rankFoods({
    required String uid,
    required List<FoodItem> foods,
  }) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) {
      // No preferences yet — return in original order with score 0
      return foods.map((f) => ScoredFood(food: f, score: 0.0)).toList();
    }

    final scored = foods.map((food) {
      final score = _calculateFoodScore(food, scores);
      return ScoredFood(food: food, score: score);
    }).toList();

    // Sort highest score first
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Gets foods the user has explicitly liked.
  Future<List<String>> getLikedFoodIds(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['likedFoodIds'] ?? []);
  }

  /// Gets foods the user has explicitly disliked.
  Future<List<String>> getDislikedFoodIds(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['dislikedFoodIds'] ?? []);
  }

  /// Gets the total number of swipes a user has made.
  Future<int> getTotalSwipes(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return 0;
    return (doc.data()?['totalSwipes'] ?? 0) as int;
  }

  /// Gets the raw tag scores for a user (useful for debugging and display).
  Future<Map<String, double>> getTagScores(String uid) async {
    return await _getTagScores(uid);
  }

  /// Gets the user's top N preferred tags (highest scores).
  Future<List<MapEntry<String, double>>> getTopTags(String uid,
      {int limit = 10}) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) return [];

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).toList();
  }

  /// Gets the user's most disliked tags (lowest/most negative scores).
  Future<List<MapEntry<String, double>>> getBottomTags(String uid,
      {int limit = 10}) async {
    final scores = await _getTagScores(uid);
    if (scores.isEmpty) return [];

    final sorted = scores.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return sorted.take(limit).toList();
  }

  /// Checks if a food has already been swiped (liked or disliked).
  Future<bool> hasBeenSwiped({
    required String uid,
    required String foodId,
  }) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return false;
    final liked = List<String>.from(doc.data()?['likedFoodIds'] ?? []);
    final disliked = List<String>.from(doc.data()?['dislikedFoodIds'] ?? []);
    return liked.contains(foodId) || disliked.contains(foodId);
  }

  /// Returns a summary of user preferences for use in Gemini prompts.
  /// This is what gets passed to the plan generator.
  Future<Map<String, dynamic>> getPreferenceSummary(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) {
      return {
        'hasPreferences': false,
        'totalSwipes': 0,
        'topTags': <String>[],
        'dislikedTags': <String>[],
        'likedFoodCount': 0,
        'dislikedFoodCount': 0,
      };
    }

    final data = doc.data()!;
    final scores = Map<String, double>.from(
      (data['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );

    // Get top liked tags (score > 0, sorted descending)
    final topTags = scores.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Get disliked tags (score < 0, sorted ascending)
    final dislikedTags = scores.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return {
      'hasPreferences': true,
      'totalSwipes': data['totalSwipes'] ?? 0,
      'topTags': topTags.take(10).map((e) => e.key).toList(),
      'topTagScores': Map.fromEntries(topTags.take(10)),
      'dislikedTags': dislikedTags.take(10).map((e) => e.key).toList(),
      'dislikedTagScores': Map.fromEntries(dislikedTags.take(10)),
      'likedFoodCount': (data['likedFoodIds'] as List?)?.length ?? 0,
      'dislikedFoodCount': (data['dislikedFoodIds'] as List?)?.length ?? 0,
    };
  }

  /// Resets all preference data for a user (useful for testing or account reset).
  Future<void> resetPreferences(String uid) async {
    await _db.collection('preferences').doc(uid).delete();
  }

  // ─── PRIVATE HELPERS ──────────────────────────────────────

  /// Reads tag scores from Firestore, applying decay to stale scores.
  Future<Map<String, double>> _getTagScores(String uid) async {
    final doc = await _db.collection('preferences').doc(uid).get();
    if (!doc.exists) return {};

    final rawScores = Map<String, double>.from(
      (doc.data()?['tagScores'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
    final updatedAt = Map<String, Timestamp>.from(
      doc.data()?['tagUpdatedAt'] as Map<String, dynamic>? ?? {},
    );

    // Apply decay to each score based on its age
    final decayed = <String, double>{};
    for (final entry in rawScores.entries) {
      final score = _applyDecay(entry.value, updatedAt[entry.key]);
      // Skip near-zero scores after decay
      if (score.abs() > 0.01) {
        decayed[entry.key] = score;
      }
    }
    return decayed;
  }

  /// Applies time-based decay to a score.
  /// Scores older than [_decayAfterDays] get multiplied by [_decayFactor]
  /// for each decay period that has passed.
  double _applyDecay(double score, Timestamp? lastUpdated) {
    if (lastUpdated == null || score == 0) return score;

    final daysSinceUpdate =
        DateTime.now().difference(lastUpdated.toDate()).inDays;

    if (daysSinceUpdate <= _decayAfterDays) return score;

    // Apply decay for each period that has passed
    final decayPeriods = (daysSinceUpdate / _decayAfterDays).floor();
    var decayed = score;
    for (int i = 0; i < decayPeriods; i++) {
      decayed *= _decayFactor;
    }
    return decayed;
  }

  /// Calculates a food's preference score from tag scores.
  double _calculateFoodScore(FoodItem food, Map<String, double> tagScores) {
    if (food.tags.isEmpty) return 0.0;
    double total = 0.0;
    for (final tag in food.tags) {
      total += tagScores[tag] ?? 0.0;
    }
    // Normalize by number of tags so foods with more tags aren't unfairly boosted
    return total / food.tags.length;
  }

  /// Returns an empty preferences document structure.
  Map<String, dynamic> _emptyPreferences() {
    return {
      'tagScores': <String, double>{},
      'tagUpdatedAt': <String, Timestamp>{},
      'likedFoodIds': <String>[],
      'dislikedFoodIds': <String>[],
      'swipeHistory': <Map<String, dynamic>>[],
      'totalSwipes': 0,
      'lastUpdated': Timestamp.now(),
    };
  }
}

/// A food item paired with its preference score for ranking.
class ScoredFood {
  final FoodItem food;
  final double score;

  const ScoredFood({required this.food, required this.score});
}
