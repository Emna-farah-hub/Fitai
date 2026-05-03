import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../core/constants/api_key.dart';
import '../models/meal_entry.dart';
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

  static const _apiKey = ApiKeys.geminiApiKey;
  final AgentTools _tools = AgentTools();
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
      final suggestion = await _coach.generateMealSuggestion(uid, suggestMealType);
      await _tools.pinToDashboard(uid, {
        'type': 'meal_suggestion',
        'message': suggestion.whySuggested,
        'severity': 'info',
        'foodSuggestion': suggestion.toJson(),
      });
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

    final suggestion = await _coach.generateMealSuggestion(uid, 'Breakfast');

    await _tools.pinToDashboard(uid, {
      'type': 'morning_briefing',
      'message': message,
      'severity': 'info',
      'foodSuggestion': suggestion.toJson(),
    });

    await _tools.logAgentAction(uid, {
      'type': 'morning_briefing',
      'trigger': 'scheduled',
      'observation': analysis.summary,
      'decision': 'Sent morning briefing',
      'action': 'pinned_message_with_suggestion',
      'outcome': 'Breakfast suggestion: ${suggestion.foodName}',
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

    final suggestion = await _coach.generateMealSuggestion(uid, 'Lunch');
    await _tools.pinToDashboard(uid, {
      'type': 'meal_suggestion',
      'message': suggestion.whySuggested,
      'severity': 'info',
      'foodSuggestion': suggestion.toJson(),
    });
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

      final suggestion = await _coach.generateMealSuggestion(uid, mealType);
      await _tools.pinToDashboard(uid, {
        'type': 'meal_reminder',
        'message': "It's been $hoursSince hours since your last meal. Time for $mealType?",
        'severity': 'info',
        'foodSuggestion': suggestion.toJson(),
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

    final analysis = await _analyst.analyze(uid);
    final profile = await _tools.getUserProfile(uid);

    final response = await _coach.generateMessage(
      analysis: analysis,
      profile: profile,
      context: 'user_message: $messageText',
    );

    Map<String, dynamic>? suggestionData;
    final lower = messageText.toLowerCase();
    if (lower.contains('what should i eat') ||
        lower.contains('suggest') ||
        lower.contains('hungry') ||
        lower.contains('meal idea')) {
      final hour = DateTime.now().hour;
      String mealType = 'Snack';
      if (hour < 10) {
        mealType = 'Breakfast';
      } else if (hour < 14) {
        mealType = 'Lunch';
      } else if (hour < 20) {
        mealType = 'Dinner';
      }

      final suggestion = await _coach.generateMealSuggestion(uid, mealType);
      suggestionData = suggestion.toJson();
    }

    await _db.collection('chat').doc(uid).collection('messages').add({
      'role': 'agent',
      'content': response,
      'timestamp': FieldValue.serverTimestamp(),
      'suggestionCard': suggestionData,
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

    final mealIndex = _buildMealIndex(mealDatabase);

    if (_apiKey.isEmpty) {
      await _saveFallbackPlan(uid, reason);
      return;
    }

    try {
      final profile = await _tools.getUserProfile(uid);
      final agentProfile =
          profile['agentProfile'] as Map<String, dynamic>? ?? {};
      final calorieTarget = (profile['dailyCalorieGoal'] ?? 2000).toInt();
      final conditions = List<String>.from(profile['conditions'] ?? []);
      final goals = List<String>.from(profile['goals'] ?? []);

      final isDiabetic = conditions
          .any((c) => c.toLowerCase().contains('diabet'));
      final isWeightLoss =
          goals.any((g) => g.toLowerCase().contains('lose'));
      final isMuscleGain =
          goals.any((g) => g.toLowerCase().contains('muscle'));

      final prefTags = await _getPreferenceTags(uid);
      final likedTags = prefTags['liked'] ?? [];
      final dislikedTags = prefTags['disliked'] ?? [];

      final existingPlan = await _db.collection('meal_plan').doc(uid).get();
      final currentVersion = existingPlan.exists
          ? ((existingPlan.data()?['version'] ?? 0) as num).toInt() + 1
          : 1;

      // Filter meal lists by mealType (capitalized in dataset)
      final breakfastMeals =
          mealDatabase.where((m) => m['mealType'] == 'Breakfast').toList();
      final lunchMeals =
          mealDatabase.where((m) => m['mealType'] == 'Lunch').toList();
      final dinnerMeals =
          mealDatabase.where((m) => m['mealType'] == 'Dinner').toList();
      final snackMeals =
          mealDatabase.where((m) => m['mealType'] == 'Snack').toList();

      // Diabetic safety filter on dinners (heaviest meal — biggest GI risk)
      final safeDinners = isDiabetic
          ? dinnerMeals.where((m) {
              final suitable = List<String>.from(m['suitableFor'] ?? []);
              final diet = List<String>.from(m['dietTags'] ?? []);
              return suitable.contains('diabetic') ||
                  diet.contains('low_gi');
            }).toList()
          : dinnerMeals;

      // Adaptation: prefer flexible meals when user keeps skipping a slot
      List<Map<String, dynamic>> filterForAdaptation(
          List<Map<String, dynamic>> meals, String mealType) {
        final key = 'prefer_flexible_${mealType.toLowerCase()}';
        if (adaptationConstraints.containsKey(key)) {
          final flexible = meals
              .where((m) =>
                  ((m['flexibilityScore'] as num?)?.toInt() ?? 0) >= 4)
              .toList();
          return flexible.isNotEmpty ? flexible : meals;
        }
        return meals;
      }

      final filteredBreakfast = filterForAdaptation(breakfastMeals, 'Breakfast');
      final filteredLunch = filterForAdaptation(lunchMeals, 'Lunch');
      final filteredDinner =
          filterForAdaptation(isDiabetic ? safeDinners : dinnerMeals, 'Dinner');
      final filteredSnack = filterForAdaptation(snackMeals, 'Snack');

      String summarizeMeal(Map<String, dynamic> m) {
        final isTunisian = m['cuisine'] == 'tunisian';
        final dietTags = (m['dietTags'] as List?)?.join(',') ?? '';
        final suitableFor = (m['suitableFor'] as List?)?.join(',') ?? '';
        return '${m['id']}: ${m['name']} | '
            '${m['calories']}kcal | P:${m['protein']}g C:${m['carbs']}g F:${m['fats']}g | '
            'GI:${m['glycemicIndex']} | flex:${m['flexibilityScore']} | '
            '${isTunisian ? 'tunisian' : m['cuisine']} | '
            'dietTags:$dietTags | suitable:$suitableFor';
      }

      final adaptationBlock = adaptationConstraints.isEmpty
          ? ''
          : '\nADAPTATIONS SEMAINE PRÉCÉDENTE:\n${adaptationConstraints.entries.map((e) => '• ${e.key}: ${e.value}').join('\n')}';

      final prompt = '''
Tu es un nutritionniste. Crée un plan de repas 7 jours pour cet utilisateur.

PROFIL:
- Calories cibles: $calorieTarget kcal/jour
- TDEE: ${profile['tdee']}
- Objectifs: $goals
- Conditions: $conditions
- Préférence alimentaire: ${profile['dietaryPreference']}
- Aliments évités: ${agentProfile['avoidedFoods'] ?? 'aucun'}
- Niveau de cuisine: ${agentProfile['cookingLevel'] ?? 'basique'}

TAGS APPRÉCIÉS (basés sur swipes): ${likedTags.join(', ')}
TAGS À ÉVITER: ${dislikedTags.join(', ')}

CONTRAINTES NUTRITIONNELLES:
- Breakfast: 250–500 kcal
- Lunch: 400–600 kcal
- Dinner: 300–560 kcal
- Snack: 90–250 kcal
- Total/jour: entre ${(calorieTarget * 0.90).round()} et ${(calorieTarget * 1.10).round()} kcal
${isDiabetic ? '⚠️ DIABÈTE: sélectionne UNIQUEMENT des repas avec "diabetic" dans suitableFor OU "low_gi" dans dietTags' : ''}
${isWeightLoss ? '→ Préférer repas avec "weight_loss" dans suitableFor et "low_calorie" dans dietTags' : ''}
${isMuscleGain ? '→ Préférer repas avec "muscle_gain" dans suitableFor et "high_protein" dans dietTags' : ''}
$adaptationBlock

PETITS-DÉJEUNERS DISPONIBLES (${filteredBreakfast.length} repas):
${filteredBreakfast.map(summarizeMeal).join('\n')}

DÉJEUNERS DISPONIBLES (${filteredLunch.length} repas):
${filteredLunch.map(summarizeMeal).join('\n')}

DÎNERS DISPONIBLES (${filteredDinner.length} repas):
${filteredDinner.map(summarizeMeal).join('\n')}

COLLATIONS DISPONIBLES (${filteredSnack.length} repas):
${filteredSnack.map(summarizeMeal).join('\n')}

RÈGLES:
1. Sélectionne UNIQUEMENT des IDs de la liste ci-dessus
2. Aucun ID répété dans la même semaine
3. Inclure au moins 40% de repas avec cuisine:tunisian
4. Varier: ne pas répéter la même source de protéine 2 jours de suite
5. Privilégier les tags: ${likedTags.take(5).join(', ')}

Retourne UNIQUEMENT ce JSON (sans markdown):
{
  "days": {
    "1": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"},
    "2": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"},
    "3": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"},
    "4": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"},
    "5": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"},
    "6": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"},
    "7": {"breakfast":"B0XX","lunch":"L0XX","dinner":"D0XX","snack":"S0XX"}
  }
}
''';

      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
        systemInstruction: Content.text(
          'Tu es un nutritionniste clinique. Tu ne renvoies que du JSON valide. '
          'Pas de markdown, pas d\'explication.',
        ),
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final cleaned = _cleanJson(response.text ?? '');
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      final geminiDays = parsed['days'] as Map<String, dynamic>? ?? {};

      // Validate, fall back per-slot if Gemini returns an unknown id
      final now = DateTime.now();
      final usedIds = <String>{};

      Map<String, dynamic> resolveMeal(
        String? id,
        List<Map<String, dynamic>> pool,
      ) {
        if (id != null && mealIndex.containsKey(id)) {
          usedIds.add(id);
          return Map<String, dynamic>.from(mealIndex[id]!);
        }
        // Pick a fallback from pool that hasn't been used yet
        final unused = pool.where((m) => !usedIds.contains(m['id'])).toList();
        final pick = (unused.isNotEmpty ? unused : pool).first;
        usedIds.add(pick['id'] as String);
        return Map<String, dynamic>.from(pick);
      }

      final days = <String, dynamic>{};
      for (int i = 1; i <= 7; i++) {
        final slot = geminiDays['$i'] as Map<String, dynamic>? ?? {};
        final date =
            DateFormat('yyyy-MM-dd').format(now.add(Duration(days: i - 1)));

        final b = resolveMeal(slot['breakfast'] as String?, filteredBreakfast);
        final l = resolveMeal(slot['lunch'] as String?, filteredLunch);
        final d = resolveMeal(slot['dinner'] as String?, filteredDinner);
        final s = resolveMeal(slot['snack'] as String?, filteredSnack);

        b['confirmed'] = false;
        b['swapped'] = false;
        l['confirmed'] = false;
        l['swapped'] = false;
        d['confirmed'] = false;
        d['swapped'] = false;
        s['confirmed'] = false;
        s['swapped'] = false;

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
        'version': currentVersion,
        'generationReason': reason,
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
            ? 'Ton plan nutritionnel personnalisé de 7 jours est prêt !'
            : 'Ton plan a été adapté selon ta semaine — découvre les nouveautés !',
        'severity': 'success',
        'foodSuggestion': null,
      });

      await _tools.logAgentAction(uid, {
        'type': 'plan_generated',
        'trigger': reason,
        'observation':
            'Plan v$currentVersion: ${likedTags.length} liked tags, ${adaptationConstraints.length} adaptations',
        'decision': 'Plan v$currentVersion created',
        'action': 'saved_to_firestore',
        'outcome': 'Plan ready',
      });
    } catch (e) {
      debugPrint('generateWeeklyPlan error: $e');
      await _saveFallbackPlan(uid, reason);
    }
  }

  Future<void> _saveFallbackPlan(String uid, String reason) async {
    final allMeals = await _loadMealDatabase();
    final profile = await _tools.getUserProfile(uid);
    final target = (profile['dailyCalorieGoal'] ?? 2000).toInt();
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

    final byType = <String, List<Map<String, dynamic>>>{};
    for (final meal in allMeals) {
      final type = meal['mealType'] as String? ?? '';
      byType.putIfAbsent(type, () => []).add(meal);
    }

    final usedIds = <String>{};

    Map<String, dynamic>? pickMeal(String type) {
      final pool = byType[type] ?? [];
      if (pool.isEmpty) return null;
      final unused = pool.where((m) => !usedIds.contains(m['id'])).toList();
      if (unused.isEmpty) {
        usedIds.clear();
        final fallback = (List<Map<String, dynamic>>.from(pool)..shuffle()).first;
        usedIds.add(fallback['id'] as String);
        return Map<String, dynamic>.from(fallback);
      }
      final meal = unused.first;
      usedIds.add(meal['id'] as String);
      return Map<String, dynamic>.from(meal);
    }

    final days = <String, dynamic>{};
    for (int i = 1; i <= 7; i++) {
      final date = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: i - 1)));
      final b = pickMeal('Breakfast');
      final l = pickMeal('Lunch');
      final d = pickMeal('Dinner');
      final s = pickMeal('Snack');

      for (final m in [b, l, d, s]) {
        if (m != null) {
          m['confirmed'] = false;
          m['swapped'] = false;
        }
      }

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

      final prefTags = await _getPreferenceTags(uid);
      final likedTags = prefTags['liked'] ?? [];

      final allMeals = await _loadMealDatabase();
      final capitalType = _capitalize(slotKey);

      final candidates = allMeals.where((m) {
        final id = m['id'] as String? ?? '';
        if (id == currentId || usedIds.contains(id)) return false;
        if (m['mealType'] != capitalType) return false;
        final cal = (m['calories'] as num?)?.toDouble() ?? 0;
        return (cal - currentCalories).abs() <= currentCalories * 0.30;
      }).toList();

      candidates.sort((a, b) {
        final aTags = [
          ...List<String>.from(a['tags'] ?? []),
          ...List<String>.from(a['dietTags'] ?? []),
        ];
        final bTags = [
          ...List<String>.from(b['tags'] ?? []),
          ...List<String>.from(b['dietTags'] ?? []),
        ];
        final aScore = aTags.where(likedTags.contains).length;
        final bScore = bTags.where(likedTags.contains).length;
        return bScore.compareTo(aScore);
      });

      return candidates.take(3).toList();
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
