import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/meal_entry.dart';
import '../services/food_scoring_service.dart';
import '../services/meal_journal_service.dart';
import 'core/agent_event.dart';
import 'tools/agent_tools.dart';
import 'agents/analyst_agent.dart';
import 'agents/coach_agent.dart';
import 'agents/guardian_agent.dart';

/// Singleton orchestrator — single entry point for all agent events.
class AgentOrchestrator {
  static final AgentOrchestrator _instance = AgentOrchestrator._();
  factory AgentOrchestrator() => _instance;
  AgentOrchestrator._();

  final AgentTools _tools = AgentTools();
  final FoodScoringService _foodScoring = FoodScoringService();
  final AnalystAgent _analyst = AnalystAgent();
  final CoachAgent _coach = CoachAgent();
  final GuardianAgent _guardian = GuardianAgent();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Track which briefings have already fired today
  final Map<String, bool> _firedToday = {};

  // Session-level cache of the meal database
  List<Map<String, dynamic>>? _cachedMealDatabase;
  DateTime? _cacheLoadedAt;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _hasFired(String eventKey) =>
      _firedToday['${_todayKey}_$eventKey'] == true;

  void _markFired(String eventKey) =>
      _firedToday['${_todayKey}_$eventKey'] = true;

  /// Main entry point for all events.
  Future<void> handle(AgentEvent event) async {
    try {
      switch (event.type) {
        case AgentEventType.appOpened:
          await _handleAppOpened(event.uid);
        case AgentEventType.mealLogged:
          await _handleMealLogged(event);
        case AgentEventType.morningBriefing:
          await _handleMorningBriefing(event.uid);
        case AgentEventType.middayCheck:
          await _handleMiddayCheck(event.uid);
        case AgentEventType.eveningSummary:
          await _handleEveningSummary(event.uid);
        case AgentEventType.weeklyReview:
          await _handleWeeklyReview(event.uid);
        case AgentEventType.onboardingComplete:
          await _handleOnboardingComplete(event.uid);
        case AgentEventType.userMessage:
          await _handleUserMessage(event);
        case AgentEventType.planUpdateRequested:
          await _handleWeeklyReview(event.uid);
        case AgentEventType.mealReminder:
          await _handleMealReminder(event.uid);
      }
    } catch (_) {
      // Orchestrator never crashes
    }
  }

  // ─── APP OPENED ─────────────────────────────────────────

  Future<void> _handleAppOpened(String uid) async {
    if (!_hasFired('morning') && DateTime.now().hour >= 6) {
      await _handleMorningBriefing(uid);
    }

    final dailyLog = await _tools.analyzeDailyLog(uid);
    final mealCount = (dailyLog['mealCount'] ?? 0) as int;
    final hour = DateTime.now().hour;

    String? suggestMealType;
    if (hour < 10 && !_mealTypeLogged(dailyLog, 'Breakfast')) {
      suggestMealType = 'Breakfast';
    } else if (hour >= 11 && hour < 14 && !_mealTypeLogged(dailyLog, 'Lunch')) {
      suggestMealType = 'Lunch';
    } else if (hour >= 17 && hour < 21 && !_mealTypeLogged(dailyLog, 'Dinner')) {
      suggestMealType = 'Dinner';
    } else if (mealCount > 0 && hour >= 14 && hour < 17) {
      suggestMealType = 'Snack';
    }

    if (suggestMealType != null) {
      final suggestion = await _buildDeterministicSuggestion(
        uid,
        suggestMealType,
        source: 'app_opened',
      );
      if (suggestion != null) {
        await _tools.pinToDashboard(uid, {
          'type': 'meal_suggestion',
          'message': suggestion.whySuggested,
          'severity': 'info',
          'foodSuggestion': suggestion.toJson(),
        });
      }
    }
  }

  bool _mealTypeLogged(Map<String, dynamic> dailyLog, String type) {
    final meals = dailyLog['meals'] as List<dynamic>? ?? [];
    return meals.any(
        (m) => (m['mealType'] as String?)?.toLowerCase() == type.toLowerCase());
  }

  // ─── MEAL LOGGED ────────────────────────────────────────

  Future<void> _handleMealLogged(AgentEvent event) async {
    final uid = event.uid;
    final mealData = event.payload;

    if (mealData.containsKey('meal')) {
      await _guardian.checkMeal(mealData['meal'], uid);
    }

    final analysis = await _analyst.analyze(uid);

    if (analysis.status != 'on_track') {
      final profile = await _tools.getUserProfile(uid);
      final message = await _coach.generateMessage(
        analysis: analysis,
        profile: profile,
        context: 'meal_logged: ${mealData['foodName'] ?? 'unknown food'}',
      );

      await _tools.pinToDashboard(uid, {
        'type': 'coaching_tip',
        'message': message,
        'severity': analysis.status == 'glycemic_risk' ? 'warning' : 'info',
        'foodSuggestion': null,
      });
    }

    await _tools.logAgentAction(uid, {
      'type': 'meal_analysis',
      'trigger': 'meal_logged',
      'observation': analysis.summary,
      'decision': analysis.status,
      'action': analysis.status != 'on_track' ? 'pinned_message' : 'none',
      'outcome': analysis.suggestedAction,
    });
  }

  // ─── MORNING BRIEFING ──────────────────────────────────

  Future<void> _handleMorningBriefing(String uid) async {
    if (_hasFired('morning')) return;
    _markFired('morning');

    final analysis = await _analyst.analyze(uid);
    final profile = await _tools.getUserProfile(uid);

    final message = await _coach.generateMessage(
      analysis: analysis,
      profile: profile,
      context: 'morning_briefing',
    );

    final suggestion = await _buildDeterministicSuggestion(
      uid,
      'Breakfast',
      source: 'morning_briefing',
    );

    await _tools.pinToDashboard(uid, {
      'type': 'morning_briefing',
      'message': message,
      'severity': 'info',
      'foodSuggestion': suggestion?.toJson(),
    });

    await _tools.logAgentAction(uid, {
      'type': 'morning_briefing',
      'trigger': 'scheduled',
      'observation': analysis.summary,
      'decision': 'Sent morning briefing',
      'action': 'pinned_message_with_suggestion',
        'outcome': suggestion == null
            ? 'No safe breakfast suggestion available'
            : 'Breakfast suggestion: ${suggestion.foodName}',
      });
  }

  // ─── MIDDAY CHECK ──────────────────────────────────────

  Future<void> _handleMiddayCheck(String uid) async {
    if (_hasFired('midday')) return;
    _markFired('midday');

    final dailyLog = await _tools.analyzeDailyLog(uid);
    final totalCal = (dailyLog['totalCalories'] ?? 0.0) as double;

    if (totalCal < 400) {
      final profile = await _tools.getUserProfile(uid);
      final analysis = AnalysisResult(
        status: 'under_eating',
        summary: 'Only ${totalCal.toInt()} calories logged by midday.',
        gaps: ['Significantly under calorie target'],
        risks: [],
        priority: 'Eat a substantial lunch',
        suggestedAction: 'Suggest a filling lunch',
        behaviorPattern: '',
        planAdjustmentNeeded: false,
      );

      final message = await _coach.generateMessage(
        analysis: analysis,
        profile: profile,
        context: 'midday_check: only ${totalCal.toInt()} cal so far',
      );

      await _tools.pinToDashboard(uid, {
        'type': 'midday_check',
        'message': message,
        'severity': 'info',
        'foodSuggestion': null,
      });
    }

    final suggestion = await _buildDeterministicSuggestion(
      uid,
      'Lunch',
      source: 'midday_check',
    );
    if (suggestion != null) {
      await _tools.pinToDashboard(uid, {
        'type': 'meal_suggestion',
        'message': suggestion.whySuggested,
        'severity': 'info',
        'foodSuggestion': suggestion.toJson(),
      });
    }
  }

  // ─── EVENING SUMMARY ──────────────────────────────────

  Future<void> _handleEveningSummary(String uid) async {
    if (_hasFired('evening')) return;
    _markFired('evening');

    final analysis = await _analyst.analyze(uid);
    final profile = await _tools.getUserProfile(uid);

    final message = await _coach.generateMessage(
      analysis: analysis,
      profile: profile,
      context: 'evening_summary',
    );

    await _tools.pinToDashboard(uid, {
      'type': 'evening_summary',
      'message': message,
      'severity': 'info',
      'foodSuggestion': null,
    });

    if (analysis.planAdjustmentNeeded) {
      await _adaptPlan(uid, analysis);
    }

    await _tools.logAgentAction(uid, {
      'type': 'evening_summary',
      'trigger': 'scheduled',
      'observation': analysis.summary,
      'decision':
          analysis.planAdjustmentNeeded ? 'Plan adaptation triggered' : 'No changes',
      'action': 'pinned_summary',
      'outcome': message,
    });
  }

  // ─── WEEKLY REVIEW (with adaptation) ──────────────────

  Future<void> _handleWeeklyReview(String uid) async {
    final adaptationConstraints = await _calculateAdaptationConstraints(uid);
    final learningSummary = await _performWeeklyLearning(uid);
    final prefTags = await _getPreferenceTags(uid);
    final analysis = await _analyst.analyze(uid);
    final profile = await _tools.getUserProfile(uid);

    await generateWeeklyPlan(
      uid,
      reason: 'weekly_adaptation',
      adaptationConstraints: adaptationConstraints,
    );

    final adherenceText = adaptationConstraints.containsKey('calorie_low')
        ? 'tu as mangé moins que prévu'
        : adaptationConstraints.containsKey('calorie_high')
            ? 'tu as dépassé ton objectif calorique'
            : 'tu as bien suivi ton plan';

    final message = await _coach.generateMessage(
      analysis: analysis,
      profile: profile,
      context: 'weekly_review: $adherenceText. '
          'Adaptations appliquées: ${adaptationConstraints.keys.join(', ')}. '
          'Tags préférés: ${(prefTags['liked'] ?? []).take(3).join(', ')}',
    );

    await _tools.pinToDashboard(uid, {
      'type': 'weekly_review',
      'message': message,
      'severity': 'info',
      'foodSuggestion': null,
    });

    final weeklyHistory = await _tools.getWeeklyHistory(uid);
    final avgCal = (weeklyHistory['averageDailyCalories'] ?? 0).toDouble();
    final target = (profile['dailyCalorieGoal'] ?? 2000).toInt();
    if (avgCal > 0 && (avgCal - target).abs() > target * 0.20) {
      final newTarget = ((avgCal + target) / 2).round();
      await _tools.updateCalorieTarget(uid, newTarget,
          'Weekly review: avg ${avgCal.toInt()} vs target $target');
    }

    await _tools.logAgentAction(uid, {
      'type': 'weekly_review_with_adaptation',
      'trigger': 'scheduled',
      'adaptationConstraints': adaptationConstraints,
      'prefTagsLiked': prefTags['liked'],
      'weeklyLearningSummary': learningSummary,
      'outcome': 'New adapted plan generated',
    });
  }

  // ─── MEAL REMINDER ────────────────────────────────────

  Future<void> _handleMealReminder(String uid) async {
    final dailyLog = await _tools.analyzeDailyLog(uid);
    final lastMealTime = dailyLog['lastMealTime'] as String?;

    if (lastMealTime == null) {
      await _tools.pinToDashboard(uid, {
        'type': 'meal_reminder',
        'message':
            "You haven't logged any meals today. Don't forget to track your food!",
        'severity': 'info',
        'foodSuggestion': null,
      });
      return;
    }

    final lastMeal = DateTime.parse(lastMealTime);
    final hoursSince = DateTime.now().difference(lastMeal).inHours;
    if (hoursSince >= 3) {
      final hour = DateTime.now().hour;
      String mealType = 'Snack';
      if (hour < 10) {
        mealType = 'Breakfast';
      } else if (hour < 14) {
        mealType = 'Lunch';
      } else if (hour < 20) {
        mealType = 'Dinner';
      }

      final suggestion = await _buildDeterministicSuggestion(
        uid,
        mealType,
        source: 'meal_reminder',
      );
      await _tools.pinToDashboard(uid, {
        'type': 'meal_reminder',
        'message': "It's been $hoursSince hours since your last meal. Time for $mealType?",
        'severity': 'info',
        'foodSuggestion': suggestion?.toJson(),
      });
    }
  }

  // ─── ONBOARDING COMPLETE ──────────────────────────────

  Future<void> _handleOnboardingComplete(String uid) async {
    await Future.delayed(const Duration(seconds: 2));
    await generateWeeklyPlan(uid, reason: 'initial');
  }

  // ─── USER MESSAGE ─────────────────────────────────────

  Future<void> _handleUserMessage(AgentEvent event) async {
    final uid = event.uid;
    final messageText = event.payload['message'] as String? ?? '';

    // 1. Save user message first (before generating reply)
    await _db.collection('chat').doc(uid).collection('messages').add({
      'role': 'user',
      'content': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'suggestionCard': null,
    });

    // 2. Load last 10 messages as conversation history (memory)
    final history = await _db
        .collection('chat')
        .doc(uid)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    final conversationHistory = history.docs.reversed
        .map((d) => '${d['role']}: ${d['content']}')
        .join('\n');

    // 3. Get analysis + profile
    final analysis = await _analyst.analyze(uid);
    final profile = await _tools.getUserProfile(uid);

    // 4. Pass history as context to CoachAgent
    final response = await _coach.generateMessage(
      analysis: analysis,
      profile: profile,
      context:
          'CONVERSATION HISTORY (last 10 messages):\n$conversationHistory\n\n'
          'CURRENT MESSAGE: $messageText\n\n'
          'IMPORTANT: You remember the full conversation above. '
          'Reference previous messages naturally when relevant.',
    );

    // 5. Detect meal suggestion intent
    final lowerText = messageText.toLowerCase();
    final wantsSuggestion = lowerText.contains('what should i eat') ||
        lowerText.contains('suggest') ||
        lowerText.contains('hungry') ||
        lowerText.contains('meal idea');

    Map<String, dynamic>? suggestionCardJson;
    if (wantsSuggestion) {
      final hour = DateTime.now().hour;
      String mealType = 'Snack';
      if (hour < 10) {
        mealType = 'Breakfast';
      } else if (hour < 14) {
        mealType = 'Lunch';
      } else if (hour < 20) {
        mealType = 'Dinner';
      }
      final suggestion = await _buildDeterministicSuggestion(
        uid,
        mealType,
        source: 'user_message',
      );
      suggestionCardJson = suggestion?.toJson();
    }

    // 6. Save agent response
    await _db.collection('chat').doc(uid).collection('messages').add({
      'role': 'agent',
      'content': response,
      'timestamp': FieldValue.serverTimestamp(),
      'suggestionCard': suggestionCardJson,
    });

    // 7. Log agent action
    await _tools.logAgentAction(uid, {
      'type': 'user_message',
      'trigger': 'chat',
      'observation': 'User said: $messageText',
      'decision': wantsSuggestion ? 'reply_with_suggestion' : 'reply',
      'action': 'agent_response',
      'outcome': response,
    });
  }

  // ─── 7-DAY PLAN GENERATION ─────────────────────────────

  Future<void> generateWeeklyPlan(
    String uid, {
    String reason = 'initial',
    Map<String, String> adaptationConstraints = const {},
  }) async {
    final mealDatabase = await _loadMealDatabase();
    if (mealDatabase.isEmpty) {
      await _saveFallbackPlan(uid, reason);
      return;
    }

    try {
      final profile = await _tools.getUserProfile(uid);
      final calorieTarget = (profile['dailyCalorieGoal'] ?? 2000).toInt();
      final conditions = List<String>.from(profile['conditions'] ?? []);
      final goals = List<String>.from(profile['goals'] ?? []);
      final goalProfile = _foodScoring.deriveGoalProfile(
        goals: goals,
        conditions: conditions,
      );
      final prefTags = await _getPreferenceTags(uid);
      final likedTags = prefTags['liked'] ?? [];
      final dislikedTags = prefTags['disliked'] ?? [];

      final existingPlan = await _db.collection('meal_plan').doc(uid).get();
      final currentVersion = existingPlan.exists
          ? ((existingPlan.data()?['version'] ?? 0) as num).toInt() + 1
          : 1;

      List<Map<String, dynamic>> filterForAdaptation(
        List<Map<String, dynamic>> meals,
        String mealType,
      ) {
        var filtered = List<Map<String, dynamic>>.from(meals);
        final flexibleKey = 'prefer_flexible_${mealType.toLowerCase()}';
        if (adaptationConstraints.containsKey(flexibleKey)) {
          final flexible = filtered
              .where((m) =>
                  ((m['flexibilityScore'] as num?)?.toInt() ?? 0) >= 4)
              .toList();
          if (flexible.isNotEmpty) {
            filtered = flexible;
          }
        }

        final avoidTags = _extractAvoidTags(adaptationConstraints);
        if (avoidTags.isNotEmpty) {
          final withoutAvoided = filtered.where((meal) {
            final mealTags = <String>{
              ...List<String>.from(meal['tags'] ?? []),
              ...List<String>.from(meal['dietTags'] ?? []),
            }.map((tag) => tag.toString().toLowerCase()).toSet();
            return avoidTags.intersection(mealTags).isEmpty;
          }).toList();
          if (withoutAvoided.isNotEmpty) {
            filtered = withoutAvoided;
          }
        }

        return filtered;
      }

      final breakfastRanked = await _foodScoring.rankMealMaps(
        uid: uid,
        meals: filterForAdaptation(
          mealDatabase.where((m) => m['mealType'] == 'Breakfast').toList(),
          'Breakfast',
        ),
        goals: goals,
        conditions: conditions,
      );
      final lunchRanked = await _foodScoring.rankMealMaps(
        uid: uid,
        meals: filterForAdaptation(
          mealDatabase.where((m) => m['mealType'] == 'Lunch').toList(),
          'Lunch',
        ),
        goals: goals,
        conditions: conditions,
      );
      final dinnerRanked = await _foodScoring.rankMealMaps(
        uid: uid,
        meals: filterForAdaptation(
          mealDatabase.where((m) => m['mealType'] == 'Dinner').toList(),
          'Dinner',
        ),
        goals: goals,
        conditions: conditions,
      );
      final snackRanked = await _foodScoring.rankMealMaps(
        uid: uid,
        meals: filterForAdaptation(
          mealDatabase.where((m) => m['mealType'] == 'Snack').toList(),
          'Snack',
        ),
        goals: goals,
        conditions: conditions,
      );

      final now = DateTime.now();
      final usedIds = <String>{};
      var previousProteinSources = <String>{};
      final days = <String, dynamic>{};

      for (int i = 1; i <= 7; i++) {
        final breakfast = _selectPlannedMeal(
          rankedMeals: breakfastRanked,
          usedIds: usedIds,
          previousProteinSources: previousProteinSources,
          targetCalories:
              _slotTargetCalories('Breakfast', adaptationConstraints),
          dayIndex: i,
        );
        final lunch = _selectPlannedMeal(
          rankedMeals: lunchRanked,
          usedIds: usedIds,
          previousProteinSources: previousProteinSources,
          targetCalories: _slotTargetCalories('Lunch', adaptationConstraints),
          dayIndex: i,
        );
        final dinner = _selectPlannedMeal(
          rankedMeals: dinnerRanked,
          usedIds: usedIds,
          previousProteinSources: previousProteinSources,
          targetCalories: _slotTargetCalories('Dinner', adaptationConstraints),
          dayIndex: i,
        );
        final snack = _selectPlannedMeal(
          rankedMeals: snackRanked,
          usedIds: usedIds,
          previousProteinSources: previousProteinSources,
          targetCalories: _slotTargetCalories('Snack', adaptationConstraints),
          dayIndex: i,
        );

        previousProteinSources = _proteinSourcesForDay([
          breakfast,
          lunch,
          dinner,
          snack,
        ]);

        days['$i'] = {
          'date': DateFormat('yyyy-MM-dd')
              .format(now.add(Duration(days: i - 1))),
          'breakfast': breakfast,
          'lunch': lunch,
          'dinner': dinner,
          'snack': snack,
          'dailyTotal': _dailyTotal([breakfast, lunch, dinner, snack]),
        };
      }

      await _tools.saveMealPlan(uid, {
        'generatedAt': FieldValue.serverTimestamp(),
        'weekStartDate': DateFormat('yyyy-MM-dd').format(now),
        'version': currentVersion,
        'generationReason': reason,
        'goalProfile': goalProfile.label,
        'dailyCalorieTarget': calorieTarget,
        'likedTagsUsed': likedTags,
        'dislikedTagsAvoided': dislikedTags,
        'adaptationConstraintsApplied': adaptationConstraints,
        'days': days,
      });

      await _db.collection('users').doc(uid).update({
        'lastPlanGeneratedAt': FieldValue.serverTimestamp(),
        'planVersion': currentVersion,
      });

      await _tools.pinToDashboard(uid, {
        'type': 'plan_ready',
        'message': reason == 'initial'
            ? 'Ton plan nutritionnel personnalise de 7 jours est pret !'
            : 'Ton plan a ete adapte selon ta semaine, avec des repas mieux notes et plus varies.',
        'severity': 'success',
        'foodSuggestion': null,
      });

      await _tools.logAgentAction(uid, {
        'type': 'plan_generated',
        'trigger': reason,
        'goalProfile': goalProfile.label,
        'observation':
            'Plan v$currentVersion: ${likedTags.length} liked tags, ${adaptationConstraints.length} adaptations',
        'decision': 'Deterministic scored meal plan created',
        'action': 'saved_to_firestore',
        'outcome': 'Plan ready',
      });
    } catch (e) {
      debugPrint('generateWeeklyPlan error: $e');
      await _saveFallbackPlan(uid, reason);
    }
  }

  Future<SuggestionCard?> _buildDeterministicSuggestion(
    String uid,
    String mealType, {
    required String source,
  }) async {
    final mealDatabase = await _loadMealDatabase();
    if (mealDatabase.isEmpty) return null;

    final profile = await _tools.getUserProfile(uid);
    final goals = List<String>.from(profile['goals'] ?? []);
    final conditions = List<String>.from(profile['conditions'] ?? []);
    final goalProfile = _foodScoring.deriveGoalProfile(
      goals: goals,
      conditions: conditions,
    );
    final dailyLog = await _tools.analyzeDailyLog(uid);
    final eatenToday = (dailyLog['meals'] as List<dynamic>? ?? [])
        .map((meal) => (meal['foodName']?.toString() ?? '').toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    final typedMeals = mealDatabase
        .where((meal) => meal['mealType'] == mealType)
        .toList();
    final pool = typedMeals
        .where((meal) =>
            !eatenToday.contains((meal['name']?.toString() ?? '').toLowerCase()))
        .toList();
    final recommendationPool = pool.isNotEmpty ? pool : typedMeals;
    if (recommendationPool.isEmpty) return null;

    final rankedMeals = await _foodScoring.rankMealMaps(
      uid: uid,
      meals: recommendationPool,
      goals: goals,
      conditions: conditions,
    );
    if (rankedMeals.isEmpty) return null;

    final primary = rankedMeals.first;
    final alternative =
        rankedMeals.length > 1 ? rankedMeals[1].meal : null;
    final suggestion = _rankedMealToSuggestionCard(
      rankedMeal: primary,
      goalProfile: goalProfile,
      alternativeMeal: alternative,
    );

    await _logMealRecommendation(
      uid: uid,
      mealType: mealType,
      rankedMeal: primary,
      source: source,
      goalProfile: goalProfile.label,
    );

    return suggestion;
  }

  SuggestionCard _rankedMealToSuggestionCard({
    required RankedMeal<Map<String, dynamic>> rankedMeal,
    required GoalProfile goalProfile,
    Map<String, dynamic>? alternativeMeal,
  }) {
    final meal = rankedMeal.meal;
    final ingredients = <String>[];
    for (final ingredient in meal['ingredients'] as List? ?? const []) {
      if (ingredient is Map) {
        final name = ingredient['name']?.toString() ?? '';
        if (name.isNotEmpty) ingredients.add(name);
      }
    }

    return SuggestionCard(
      foodName: meal['name']?.toString() ?? '',
      portion: _portionFromMeal(meal),
      calories: (meal['calories'] as num?)?.toDouble() ?? 0,
      protein: (meal['protein'] as num?)?.toDouble() ?? 0,
      carbs: (meal['carbs'] as num?)?.toDouble() ?? 0,
      fats: (meal['fats'] as num?)?.toDouble() ?? 0,
      gi: (meal['glycemicIndex'] as num?)?.toInt() ?? 0,
      whySuggested: _suggestionReason(
        meal: meal,
        goalProfile: goalProfile,
        rankedMeal: rankedMeal,
      ),
      quickPreparationTip: _preparationTip(
        meal: meal,
        ingredients: ingredients,
      ),
      alternativeOption: alternativeMeal?['name']?.toString() ?? '',
    );
  }

  String _suggestionReason({
    required Map<String, dynamic> meal,
    required GoalProfile goalProfile,
    required RankedMeal<Map<String, dynamic>> rankedMeal,
  }) {
    final protein = (meal['protein'] as num?)?.toInt() ?? 0;
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;
    final gi = (meal['glycemicIndex'] as num?)?.toInt() ?? 0;
    final roundedScore = (rankedMeal.finalScore * 100).round();

    if (goalProfile.isDiabetes) {
      return '${meal['name']} is goal-safe for diabetes with GI $gi, controlled carbs, and a score of $roundedScore/100.';
    }
    if (goalProfile.isMuscleGain) {
      return '${meal['name']} supports muscle gain with $protein g protein, $calories kcal, and a score of $roundedScore/100.';
    }
    if (goalProfile.isWeightLoss) {
      return '${meal['name']} fits weight loss with $calories kcal, balanced protein, and a score of $roundedScore/100.';
    }
    return '${meal['name']} is one of your top scored meals right now with $protein g protein and a score of $roundedScore/100.';
  }

  String _preparationTip({
    required Map<String, dynamic> meal,
    required List<String> ingredients,
  }) {
    final prepTime = meal['prepTime']?.toString();
    if (ingredients.length >= 2) {
      return 'Keep it simple: build it around ${ingredients[0]} and ${ingredients[1]}${prepTime == null ? '' : ' in about $prepTime'}.';
    }
    if (prepTime != null && prepTime.isNotEmpty) {
      return 'This meal is a practical option you can prepare in about $prepTime.';
    }
    return 'Prep this as a simple, goal-safe meal using the ingredients already listed in your plan.';
  }

  double _portionFromMeal(Map<String, dynamic> meal) {
    double totalQuantity = 0;
    for (final ingredient in meal['ingredients'] as List? ?? const []) {
      if (ingredient is Map) {
        totalQuantity += ((ingredient['quantity'] as num?)?.toDouble() ?? 0);
      }
    }
    return totalQuantity > 0 ? totalQuantity : 100;
  }

  Future<void> _logMealRecommendation({
    required String uid,
    required String mealType,
    required RankedMeal<Map<String, dynamic>> rankedMeal,
    required String source,
    required String goalProfile,
  }) async {
    try {
      await _db
          .collection('meal_recommendations')
          .doc(uid)
          .collection('events')
          .add({
        'createdAt': Timestamp.now(),
        'mealType': mealType,
        'source': source,
        'goalProfile': goalProfile,
        'foodName': rankedMeal.meal['name'],
        'mealId': rankedMeal.meal['id'],
        'goalCompatibilityScore': rankedMeal.goalCompatibilityScore,
        'preferenceScore': rankedMeal.preferenceScore,
        'finalScore': rankedMeal.finalScore,
        'meal': rankedMeal.meal,
      });
    } catch (_) {}
  }

  Map<String, dynamic>? _selectPlannedMeal({
    required List<RankedMeal<Map<String, dynamic>>> rankedMeals,
    required Set<String> usedIds,
    required Set<String> previousProteinSources,
    required double targetCalories,
    required int dayIndex,
  }) {
    if (rankedMeals.isEmpty) return null;

    final shortlist = rankedMeals.take(rankedMeals.length < 6 ? rankedMeals.length : 6).toList();
    RankedMeal<Map<String, dynamic>>? best;
    var bestScore = -9999.0;

    for (int i = 0; i < shortlist.length; i++) {
      final candidate = shortlist[i];
      final meal = candidate.meal;
      final id = meal['id']?.toString() ?? '';
      if (id.isNotEmpty && usedIds.contains(id)) continue;

      final proteinSources = _proteinSourcesForMeal(meal);
      final hasRepeatedProtein =
          proteinSources.intersection(previousProteinSources).isNotEmpty;
      final calories = (meal['calories'] as num?)?.toDouble() ?? targetCalories;
      final caloriePenalty = targetCalories <= 0
          ? 0.0
          : ((calories - targetCalories).abs() / targetCalories).clamp(0.0, 1.0);
      final rotationBonus = i == (dayIndex % shortlist.length) ? 0.02 : 0.0;
      final varietyPenalty = hasRepeatedProtein ? 0.18 : 0.0;
      final candidateScore =
          candidate.finalScore - (caloriePenalty * 0.08) - varietyPenalty + rotationBonus;

      if (candidateScore > bestScore) {
        best = candidate;
        bestScore = candidateScore;
      }
    }

    best ??= rankedMeals.firstWhere(
      (candidate) {
        final id = candidate.meal['id']?.toString() ?? '';
        return id.isEmpty || !usedIds.contains(id);
      },
      orElse: () => rankedMeals.first,
    );

    final selected = Map<String, dynamic>.from(best.meal);
    selected['confirmed'] = false;
    selected['swapped'] = false;
    selected['goalCompatibilityScore'] =
        double.parse(best.goalCompatibilityScore.toStringAsFixed(3));
    selected['preferenceScore'] =
        double.parse(best.preferenceScore.toStringAsFixed(3));
    selected['finalScore'] =
        double.parse(best.finalScore.toStringAsFixed(3));

    final id = selected['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      usedIds.add(id);
    }
    return selected;
  }

  double _slotTargetCalories(
    String mealType,
    Map<String, String> adaptationConstraints,
  ) {
    double target;
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        target = 375.0;
        break;
      case 'lunch':
        target = 500.0;
        break;
      case 'dinner':
        target = 430.0;
        break;
      case 'snack':
        target = 170.0;
        break;
      default:
        target = 350.0;
    }

    if (adaptationConstraints.containsKey('calorie_low')) {
      target += mealType.toLowerCase() == 'snack' ? 40 : 30;
    }
    if (adaptationConstraints.containsKey('calorie_high')) {
      target -= mealType.toLowerCase() == 'snack' ? 25 : 20;
    }
    return target;
  }

  Set<String> _extractAvoidTags(Map<String, String> adaptationConstraints) {
    final raw = adaptationConstraints['avoid_swapped_tags'];
    if (raw == null || raw.isEmpty) return {};
    final marker = raw.split(':');
    if (marker.length < 2) return {};
    return marker.last
        .split(',')
        .map((tag) => tag.trim().toLowerCase().replaceAll('.', ''))
        .where((tag) => tag.isNotEmpty)
        .toSet();
  }

  Set<String> _proteinSourcesForDay(List<Map<String, dynamic>?> meals) {
    final proteins = <String>{};
    for (final meal in meals) {
      if (meal == null) continue;
      proteins.addAll(_proteinSourcesForMeal(meal));
    }
    return proteins;
  }

  Set<String> _proteinSourcesForMeal(Map<String, dynamic> meal) {
    final tokens = <String>{};
    for (final ingredient in meal['ingredients'] as List? ?? const []) {
      if (ingredient is Map) {
        final name = ingredient['name']?.toString().toLowerCase() ?? '';
        if (name.isNotEmpty) tokens.add(name);
      }
    }
    for (final tag in List<String>.from(meal['tags'] ?? const [])) {
      tokens.add(tag.toLowerCase());
    }
    for (final tag in List<String>.from(meal['dietTags'] ?? const [])) {
      tokens.add(tag.toLowerCase());
    }

    const knownProteins = [
      'chicken',
      'turkey',
      'beef',
      'lamb',
      'fish',
      'salmon',
      'tuna',
      'egg',
      'eggs',
      'yogurt',
      'cheese',
      'lentil',
      'lentils',
      'bean',
      'beans',
      'chickpea',
      'chickpeas',
      'legume',
      'shrimp',
    ];

    final matched = <String>{};
    for (final token in tokens) {
      for (final protein in knownProteins) {
        if (token.contains(protein)) {
          matched.add(protein);
        }
      }
    }

    if (matched.isEmpty && tokens.isNotEmpty) {
      matched.add(tokens.first);
    }
    return matched;
  }

  Future<Map<String, dynamic>> _performWeeklyLearning(String uid) async {
    final planDoc = await _db.collection('meal_plan').doc(uid).get();
    final days = planDoc.data()?['days'] as Map<String, dynamic>? ?? {};
    var planRecommendedCount = 0;

    final eatenMeals = <Map<String, dynamic>>[];
    final skippedMeals = <Map<String, dynamic>>[];
    for (final dayData in days.values) {
      final day = dayData as Map<String, dynamic>;
      for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
        final meal = day[mealType] as Map<String, dynamic>?;
        if (meal == null) continue;
        planRecommendedCount++;
        if (meal['confirmed'] == true) {
          eatenMeals.add(Map<String, dynamic>.from(meal));
        } else {
          skippedMeals.add(Map<String, dynamic>.from(meal));
        }
      }
    }

    final recommendationEvents = await _db
        .collection('meal_recommendations')
        .doc(uid)
        .collection('events')
        .get();
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentRecommendations = recommendationEvents.docs
        .map((doc) => doc.data())
        .where((event) {
          final createdAt = event['createdAt'];
          if (createdAt is! Timestamp) return false;
          return createdAt.toDate().isAfter(weekAgo);
        })
        .toList();

    final preferenceDoc = await _db.collection('preferences').doc(uid).get();
    final allSwipeHistory = List<Map<String, dynamic>>.from(
      preferenceDoc.data()?['swipeHistory'] ?? const [],
    );
    final recentSwipes = allSwipeHistory.where((swipe) {
      final ts = swipe['timestamp'];
      if (ts is! Timestamp) return false;
      return ts.toDate().isAfter(weekAgo);
    }).map((swipe) => Map<String, dynamic>.from(swipe)).toList();

    var eatenRecommendations = 0;
    for (int i = 0; i < 7; i++) {
      final dateKey = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: i)));
      final entries = await _db
          .collection('meals')
          .doc(uid)
          .collection('logs')
          .doc(dateKey)
          .collection('entries')
          .get();
      for (final entry in entries.docs) {
        final inputMethod = entry.data()['inputMethod']?.toString() ?? '';
        if (inputMethod == 'agent_suggestion' || inputMethod == 'plan_confirmed') {
          eatenRecommendations++;
        }
      }
    }

    await _foodScoring.applyWeeklyLearning(
      uid: uid,
      eatenMeals: eatenMeals,
      skippedMeals: skippedMeals,
      swipeHistory: recentSwipes,
      recommendedMeals: recentRecommendations.length + planRecommendedCount,
      eatenRecommendations: eatenRecommendations,
      skippedRecommendations: skippedMeals.length,
    );

    return {
      'recommendedMeals': recentRecommendations.length + planRecommendedCount,
      'eatenMeals': eatenMeals.length,
      'skippedMeals': skippedMeals.length,
      'swipeEvents': recentSwipes.length,
    };
  }

  Future<void> _saveFallbackPlan(String uid, String reason) async {
    final allMeals = await _loadMealDatabase();
    final profile = await _tools.getUserProfile(uid);
    final target = (profile['dailyCalorieGoal'] ?? 2000).toInt();
    final goals = List<String>.from(profile['goals'] ?? []);
    final conditions = List<String>.from(profile['conditions'] ?? []);
    final now = DateTime.now();

    if (allMeals.isEmpty) {
      // No DB at all — minimal placeholder so user isn't stuck
      await _tools.saveMealPlan(uid, {
        'generatedAt': FieldValue.serverTimestamp(),
        'weekStartDate': DateFormat('yyyy-MM-dd').format(now),
        'version': 1,
        'generationReason': '$reason (empty_db)',
        'dailyCalorieTarget': target,
        'days': <String, dynamic>{},
      });
      return;
    }

    final breakfastRanked = await _foodScoring.rankMealMaps(
      uid: uid,
      meals: allMeals.where((meal) => meal['mealType'] == 'Breakfast').toList(),
      goals: goals,
      conditions: conditions,
    );
    final lunchRanked = await _foodScoring.rankMealMaps(
      uid: uid,
      meals: allMeals.where((meal) => meal['mealType'] == 'Lunch').toList(),
      goals: goals,
      conditions: conditions,
    );
    final dinnerRanked = await _foodScoring.rankMealMaps(
      uid: uid,
      meals: allMeals.where((meal) => meal['mealType'] == 'Dinner').toList(),
      goals: goals,
      conditions: conditions,
    );
    final snackRanked = await _foodScoring.rankMealMaps(
      uid: uid,
      meals: allMeals.where((meal) => meal['mealType'] == 'Snack').toList(),
      goals: goals,
      conditions: conditions,
    );

    final usedIds = <String>{};

    Map<String, dynamic>? pickMeal(List<RankedMeal<Map<String, dynamic>>> ranked) {
      if (ranked.isEmpty) return null;
      for (final candidate in ranked) {
        final id = candidate.meal['id']?.toString() ?? '';
        if (!usedIds.contains(id)) {
          final meal = Map<String, dynamic>.from(candidate.meal);
          meal['confirmed'] = false;
          meal['swapped'] = false;
          meal['goalCompatibilityScore'] =
              double.parse(candidate.goalCompatibilityScore.toStringAsFixed(3));
          meal['preferenceScore'] =
              double.parse(candidate.preferenceScore.toStringAsFixed(3));
          meal['finalScore'] =
              double.parse(candidate.finalScore.toStringAsFixed(3));
          if (id.isNotEmpty) usedIds.add(id);
          return meal;
        }
      }
      return null;
    }

    final days = <String, dynamic>{};
    for (int i = 1; i <= 7; i++) {
      final date = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: i - 1)));
      final b = pickMeal(breakfastRanked);
      final l = pickMeal(lunchRanked);
      final d = pickMeal(dinnerRanked);
      final s = pickMeal(snackRanked);

      days['$i'] = {
        'date': date,
        'breakfast': b,
        'lunch': l,
        'dinner': d,
        'snack': s,
        'dailyTotal': _dailyTotal([b, l, d, s]),
      };
    }

    await _tools.saveMealPlan(uid, {
      'generatedAt': FieldValue.serverTimestamp(),
      'weekStartDate': DateFormat('yyyy-MM-dd').format(now),
      'version': 1,
      'generationReason': '$reason (fallback)',
      'dailyCalorieTarget': target,
      'days': days,
    });

    await _tools.pinToDashboard(uid, {
      'type': 'plan_ready',
      'message':
          "Ton plan de départ est prêt ! Log tes repas pour que je l'adapte à toi.",
      'severity': 'success',
      'foodSuggestion': null,
    });
  }

  Map<String, int> _dailyTotal(List<Map<String, dynamic>?> meals) {
    double cal = 0, p = 0, c = 0, f = 0;
    for (final m in meals) {
      if (m == null) continue;
      cal += (m['calories'] as num?)?.toDouble() ?? 0;
      p += (m['protein'] as num?)?.toDouble() ?? 0;
      c += (m['carbs'] as num?)?.toDouble() ?? 0;
      f += (m['fats'] as num?)?.toDouble() ?? 0;
    }
    return {
      'calories': cal.round(),
      'protein': p.round(),
      'carbs': c.round(),
      'fats': f.round(),
    };
  }

  Future<void> _adaptPlan(String uid, AnalysisResult analysis) async {
    if (analysis.status == 'glycemic_risk' ||
        analysis.status == 'under_eating') {
      await generateWeeklyPlan(uid, reason: 'mid_week_adaptation');
    }
  }

  // ─── PLAN INTERACTION (UI) ────────────────────────────

  /// Called when the user taps "I ate this" on a planned meal.
  Future<void> confirmPlannedMeal({
    required String uid,
    required int dayNumber,
    required String mealType, // "breakfast" | "lunch" | "dinner" | "snack"
  }) async {
    try {
      final now = DateTime.now();
      final planDoc = await _db.collection('meal_plan').doc(uid).get();
      if (!planDoc.exists) return;

      final days = Map<String, dynamic>.from(planDoc.data()?['days'] ?? {});
      final day = Map<String, dynamic>.from(days['$dayNumber'] ?? {});
      final slotKey = mealType.toLowerCase();
      final meal = Map<String, dynamic>.from(day[slotKey] ?? {});
      if (meal.isEmpty) return;

      final dateStr =
          meal['date'] as String? ?? DateFormat('yyyy-MM-dd').format(now);

      double totalQuantity = 0;
      final ingredients = meal['ingredients'] as List? ?? [];
      for (final ing in ingredients) {
        if (ing is Map) {
          totalQuantity += ((ing['quantity'] as num?)?.toDouble() ?? 0);
        }
      }
      if (totalQuantity == 0) totalQuantity = 100;

      final entry = MealEntry(
        id: '${dayNumber}_${slotKey}_${now.millisecondsSinceEpoch}',
        userId: uid,
        date: dateStr,
        foodName: meal['name'] as String? ?? '',
        quantity: totalQuantity,
        calories: (meal['calories'] as num?)?.toDouble() ?? 0,
        protein: (meal['protein'] as num?)?.toDouble() ?? 0,
        carbs: (meal['carbs'] as num?)?.toDouble() ?? 0,
        fats: (meal['fats'] as num?)?.toDouble() ?? 0,
        glycemicIndex: (meal['glycemicIndex'] as num?)?.toInt() ?? 0,
        mealType: _capitalize(slotKey),
        inputMethod: 'plan_confirmed',
        timestamp: now,
      );

      await MealJournalService().addMeal(uid, entry);

      meal['confirmed'] = true;
      day[slotKey] = meal;
      days['$dayNumber'] = day;

      await _db.collection('meal_plan').doc(uid).update({'days': days});
    } catch (e) {
      debugPrint('confirmPlannedMeal error: $e');
    }
  }

  /// Returns up to 3 alternative meals the user can swap to.
  Future<List<Map<String, dynamic>>> getSwapAlternatives({
    required String uid,
    required int dayNumber,
    required String mealType, // "breakfast" | "lunch" | "dinner" | "snack"
  }) async {
    try {
      final planDoc = await _db.collection('meal_plan').doc(uid).get();
      if (!planDoc.exists) return [];

      final days = planDoc.data()?['days'] as Map<String, dynamic>? ?? {};
      final day = days['$dayNumber'] as Map<String, dynamic>? ?? {};
      final slotKey = mealType.toLowerCase();
      final currentMeal = day[slotKey] as Map<String, dynamic>? ?? {};
      final currentCalories =
          (currentMeal['calories'] as num?)?.toDouble() ?? 300;
      final currentId = currentMeal['id'] as String? ?? '';

      // All IDs already used in the week
      final usedIds = <String>{};
      for (final d in days.values) {
        final dayMap = d as Map<String, dynamic>;
        for (final mt in ['breakfast', 'lunch', 'dinner', 'snack']) {
          final m = dayMap[mt] as Map<String, dynamic>?;
          if (m != null) usedIds.add(m['id'] as String? ?? '');
        }
      }

      final profile = await _tools.getUserProfile(uid);
      final goals = List<String>.from(profile['goals'] ?? []);
      final conditions = List<String>.from(profile['conditions'] ?? []);
      final allMeals = await _loadMealDatabase();
      final capitalType = _capitalize(slotKey);

      final candidates = allMeals.where((m) {
        final id = m['id'] as String? ?? '';
        if (id == currentId || usedIds.contains(id)) return false;
        if (m['mealType'] != capitalType) return false;
        final cal = (m['calories'] as num?)?.toDouble() ?? 0;
        return (cal - currentCalories).abs() <= currentCalories * 0.30;
      }).toList();
      final ranked = await _foodScoring.rankMealMaps(
        uid: uid,
        meals: candidates,
        goals: goals,
        conditions: conditions,
      );
      return ranked.take(3).map((rankedMeal) {
        final meal = Map<String, dynamic>.from(rankedMeal.meal);
        meal['goalCompatibilityScore'] =
            double.parse(rankedMeal.goalCompatibilityScore.toStringAsFixed(3));
        meal['preferenceScore'] =
            double.parse(rankedMeal.preferenceScore.toStringAsFixed(3));
        meal['finalScore'] =
            double.parse(rankedMeal.finalScore.toStringAsFixed(3));
        return meal;
      }).toList();
    } catch (e) {
      debugPrint('getSwapAlternatives error: $e');
      return [];
    }
  }

  /// Replaces the planned meal with the chosen alternative and logs it.
  Future<void> confirmSwap({
    required String uid,
    required int dayNumber,
    required String mealType,
    required Map<String, dynamic> chosenMeal,
  }) async {
    try {
      final planDoc = await _db.collection('meal_plan').doc(uid).get();
      if (!planDoc.exists) return;

      final days = Map<String, dynamic>.from(planDoc.data()?['days'] ?? {});
      final day = Map<String, dynamic>.from(days['$dayNumber'] ?? {});
      final slotKey = mealType.toLowerCase();

      final newMeal = Map<String, dynamic>.from(chosenMeal);
      newMeal['confirmed'] = true;
      newMeal['swapped'] = true;
      day[slotKey] = newMeal;

      day['dailyTotal'] = _dailyTotal([
        day['breakfast'] as Map<String, dynamic>?,
        day['lunch'] as Map<String, dynamic>?,
        day['dinner'] as Map<String, dynamic>?,
        day['snack'] as Map<String, dynamic>?,
      ]);

      days['$dayNumber'] = day;
      await _db.collection('meal_plan').doc(uid).update({'days': days});

      // Also log the swapped meal as eaten
      await confirmPlannedMeal(
        uid: uid,
        dayNumber: dayNumber,
        mealType: slotKey,
      );
    } catch (e) {
      debugPrint('confirmSwap error: $e');
    }
  }

  // ─── HELPERS ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _loadMealDatabase() async {
    if (_cachedMealDatabase != null && _cacheLoadedAt != null) {
      if (DateTime.now().difference(_cacheLoadedAt!).inMinutes < 30) {
        return _cachedMealDatabase!;
      }
    }

    try {
      final snap = await _db.collection('tunisian_meals').get();
      _cachedMealDatabase = snap.docs.map((d) => d.data()).toList();
      _cacheLoadedAt = DateTime.now();
      return _cachedMealDatabase!;
    } catch (_) {
      return _cachedMealDatabase ?? [];
    }
  }

  Map<String, Map<String, dynamic>> _buildMealIndex(
      List<Map<String, dynamic>> meals) {
    return {for (final m in meals) m['id'] as String: m};
  }

  Future<Map<String, List<String>>> _getPreferenceTags(String uid) async {
    try {
      final prefs = await _db.collection('preferences').doc(uid).get();
      if (!prefs.exists) return {'liked': [], 'disliked': []};

      final raw = prefs.data()?['tagScores'] as Map<String, dynamic>? ?? {};
      final tagScores = <String, double>{
        for (final e in raw.entries) e.key: (e.value as num).toDouble(),
      };
      final sorted = tagScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'liked': sorted
            .where((e) => e.value > 0)
            .take(8)
            .map((e) => e.key)
            .toList(),
        'disliked': sorted
            .where((e) => e.value < 0)
            .take(5)
            .map((e) => e.key)
            .toList(),
      };
    } catch (_) {
      return {'liked': [], 'disliked': []};
    }
  }

  Future<Map<String, String>> _calculateAdaptationConstraints(
      String uid) async {
    try {
      final constraints = <String, String>{};
      final planDoc = await _db.collection('meal_plan').doc(uid).get();
      if (!planDoc.exists) return constraints;

      final days = planDoc.data()?['days'] as Map<String, dynamic>? ?? {};

      final confirmedCount = {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
        'snack': 0
      };
      final skippedCount = {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
        'snack': 0
      };
      double totalPlannedCal = 0;
      double totalActualCal = 0;
      final swappedTags = <String>[];

      for (final dayData in days.values) {
        final day = dayData as Map<String, dynamic>;
        for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
          final meal = day[mealType] as Map<String, dynamic>?;
          if (meal == null) continue;
          final cal = (meal['calories'] as num?)?.toDouble() ?? 0;
          totalPlannedCal += cal;
          if (meal['confirmed'] == true) {
            confirmedCount[mealType] = (confirmedCount[mealType] ?? 0) + 1;
            totalActualCal += cal;
            if (meal['swapped'] == true) {
              swappedTags.addAll(List<String>.from(meal['tags'] ?? []));
              swappedTags.addAll(List<String>.from(meal['dietTags'] ?? []));
            }
          } else {
            skippedCount[mealType] = (skippedCount[mealType] ?? 0) + 1;
          }
        }
      }

      // Rule 1: Skipped ≥ 4 times → quick/easy preference
      for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
        if ((skippedCount[mealType] ?? 0) >= 4) {
          constraints['skip_$mealType'] =
              'User skipped $mealType ${skippedCount[mealType]} times. '
              'Prefer meals tagged: quick_prep, no_cook, easy.';
        }
      }

      // Rule 2: Calorie adherence
      if (totalPlannedCal > 0) {
        final adherence = totalActualCal / totalPlannedCal;
        if (adherence < 0.75) {
          constraints['calorie_low'] =
              'User consumed only ${(adherence * 100).round()}% of planned calories. '
              'Suggest more filling meals; bump snack calories.';
        } else if (adherence > 1.15) {
          constraints['calorie_high'] =
              'User consistently exceeded calorie target. '
              'Reduce portion sizes and suggest lighter options.';
        }
      }

      // Rule 3: Frequently swapped tags
      if (swappedTags.isNotEmpty) {
        final tagCount = <String, int>{};
        for (final t in swappedTags) {
          tagCount[t] = (tagCount[t] ?? 0) + 1;
        }
        final topSwapped = tagCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (topSwapped.isNotEmpty) {
          constraints['avoid_swapped_tags'] =
              'User frequently swapped meals tagged: '
              '${topSwapped.take(3).map((e) => e.key).join(', ')}. '
              'Reduce these in next plan.';
        }
      }

      // Rule 4: Skipped ≥ 3 → flexibility-based filtering at generation time
      for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
        if ((skippedCount[mealType] ?? 0) >= 3) {
          constraints['prefer_flexible_$mealType'] =
              'User skipped $mealType frequently. '
              'Prefer meals with flexibilityScore >= 4 and availability: high.';
        }
      }

      return constraints;
    } catch (_) {
      return {};
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _cleanJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }
    return cleaned.trim();
  }
}
