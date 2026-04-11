import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
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

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  final AgentTools _tools = AgentTools();
  final AnalystAgent _analyst = AnalystAgent();
  final CoachAgent _coach = CoachAgent();
  final GuardianAgent _guardian = GuardianAgent();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Track which briefings have already fired today
  final Map<String, bool> _firedToday = {};

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

    // Check if a meal suggestion should show
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
        'message': '${suggestion.whySuggested}',
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

    // Guardian checks glycemic risk (no Gemini)
    if (mealData.containsKey('meal')) {
      await _guardian.checkMeal(mealData['meal'], uid);
    }

    // Analyst runs analysis
    final analysis = await _analyst.analyze(uid);

    // If there's an issue, coach generates message
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

    final suggestion =
        await _coach.generateMealSuggestion(uid, 'Breakfast');

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
      'decision': analysis.planAdjustmentNeeded ? 'Plan adaptation triggered' : 'No changes',
      'action': 'pinned_summary',
      'outcome': message,
    });
  }

  // ─── WEEKLY REVIEW ────────────────────────────────────

  Future<void> _handleWeeklyReview(String uid) async {
    final analysis = await _analyst.analyze(uid);
    final profile = await _tools.getUserProfile(uid);
    final weeklyHistory = await _tools.getWeeklyHistory(uid);

    // Always adapt the plan on weekly review
    await _adaptPlan(uid, analysis);

    final message = await _coach.generateMessage(
      analysis: analysis,
      profile: profile,
      context: 'weekly_review: consistency=${weeklyHistory['consistencyScore']}%',
    );

    await _tools.pinToDashboard(uid, {
      'type': 'weekly_review',
      'message': message,
      'severity': 'info',
      'foodSuggestion': null,
    });

    // Update calorie target if consistently off
    final avgCal = (weeklyHistory['averageDailyCalories'] ?? 0).toDouble();
    final target = (profile['dailyCalorieGoal'] ?? 2000).toInt();
    if (avgCal > 0 && (avgCal - target).abs() > target * 0.2) {
      final newTarget = ((avgCal + target) / 2).round();
      await _tools.updateCalorieTarget(
        uid,
        newTarget,
        'Weekly review: avg ${avgCal.toInt()} vs target $target',
      );
    }

    await _tools.logAgentAction(uid, {
      'type': 'weekly_review',
      'trigger': 'scheduled',
      'observation': 'Consistency: ${weeklyHistory['consistencyScore']}%, '
          'Avg cal: ${avgCal.toInt()}',
      'decision': 'Plan adapted',
      'action': 'pinned_weekly_review',
      'outcome': message,
    });
  }

  // ─── MEAL REMINDER ────────────────────────────────────

  Future<void> _handleMealReminder(String uid) async {
    final dailyLog = await _tools.analyzeDailyLog(uid);
    final lastMealTime = dailyLog['lastMealTime'] as String?;

    if (lastMealTime == null) {
      await _tools.pinToDashboard(uid, {
        'type': 'meal_reminder',
        'message': "You haven't logged any meals today. Don't forget to track your food!",
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
      if (hour < 10) mealType = 'Breakfast';
      else if (hour < 14) mealType = 'Lunch';
      else if (hour < 20) mealType = 'Dinner';

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
    await generateThirtyDayPlan(uid, reason: 'initial');
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

    // Save agent response to chat
    Map<String, dynamic>? suggestionData;
    final lower = messageText.toLowerCase();
    if (lower.contains('what should i eat') ||
        lower.contains('suggest') ||
        lower.contains('hungry') ||
        lower.contains('meal idea')) {
      final hour = DateTime.now().hour;
      String mealType = 'Snack';
      if (hour < 10) mealType = 'Breakfast';
      else if (hour < 14) mealType = 'Lunch';
      else if (hour < 20) mealType = 'Dinner';

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

  // ─── 30-DAY PLAN GENERATION ───────────────────────────

  Future<void> generateThirtyDayPlan(String uid, {String reason = 'initial'}) async {
    if (_apiKey.isEmpty) {
      await _saveFallbackPlan(uid, reason);
      return;
    }

    try {
      final profile = await _tools.getUserProfile(uid);
      final weeklyHistory = await _tools.getWeeklyHistory(uid);
      final analysis = await _analyst.analyze(uid);
      final agentProfile =
          profile['agentProfile'] as Map<String, dynamic>? ?? {};

      // Get current plan version
      final existingPlan =
          await _db.collection('meal_plan').doc(uid).get();
      final currentVersion =
          existingPlan.exists ? (existingPlan.data()?['version'] ?? 0) + 1 : 1;

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content.text(
          'You are a clinical nutritionist creating a 30-day meal plan. '
          'Return ONLY valid JSON. No markdown fences. No explanation.',
        ),
      );

      final prompt = '''
Create a personalized 30-day meal plan based on this data:

USER BIOMETRICS:
- Name: ${profile['name']}, Age: ${profile['age']}, Sex: ${profile['sex']}
- Height: ${profile['height']}cm, Weight: ${profile['weight']}kg
- Activity: ${profile['activityLevel']}, Fitness: ${profile['fitnessLevel']}
- BMR: ${profile['bmr']}, TDEE: ${profile['tdee']}
- Daily calorie target: ${profile['dailyCalorieGoal']}

HEALTH:
- Goals: ${profile['goals']}
- Conditions: ${profile['conditions']}
- Dietary preference: ${profile['dietaryPreference']}

AGENT PROFILE (user preferences):
- Preferred foods: ${agentProfile['preferredFoods'] ?? 'not set'}
- Avoided foods: ${agentProfile['avoidedFoods'] ?? 'none'}
- Cooking level: ${agentProfile['cookingLevel'] ?? 'basic'}
- Budget: ${agentProfile['budget'] ?? 'medium'}
- Meals per day: ${agentProfile['mealsPerDay'] ?? '3'}
- Problem meal: ${agentProfile['problemMeal'] ?? 'none'}
- Wake time: ${agentProfile['wakeTime'] ?? '7:00'}
- Sleep time: ${agentProfile['sleepTime'] ?? '23:00'}
${agentProfile['diabetesDetails'] != null ? '- Diabetes details: ${agentProfile['diabetesDetails']}' : ''}

BEHAVIOR (last 7 days):
${jsonEncode(weeklyHistory)}

CURRENT ANALYSIS:
${jsonEncode(analysis.toJson())}

Return this JSON structure:
{
  "dailyCalorieTarget": number,
  "targetMacros": {"protein": grams, "carbs": grams, "fats": grams},
  "days": {
    "1": {
      "date": "YYYY-MM-DD",
      "breakfast": {
        "suggestion": "food name",
        "portion": grams,
        "calories": number,
        "protein": number,
        "carbs": number,
        "fats": number,
        "gi": number,
        "recipe": "one sentence preparation tip",
        "tunisianAlternative": "local dish name"
      },
      "lunch": same structure,
      "dinner": same structure,
      "snack": same structure,
      "dailyTotal": {"calories": number, "protein": number, "carbs": number, "fats": number},
      "theme": "high protein day" or "recovery day" or "normal day"
    }
  },
  "weeklyThemes": {
    "week1": "establishment — building the habit",
    "week2": "progression — increasing protein",
    "week3": "adaptation — variety introduced",
    "week4": "consolidation — refining what works"
  },
  "adaptationNotes": "why this plan was structured this way"
}

IMPORTANT: Generate ALL 30 days. Start date is ${DateFormat('yyyy-MM-dd').format(DateTime.now())}.
Include Tunisian dishes the user likes. Respect avoided foods and cooking level.
If diabetic, keep all meals GI <= 55 where possible.
''';

      final response =
          await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final cleaned = _cleanJson(text);
      final planData = jsonDecode(cleaned) as Map<String, dynamic>;

      await _tools.saveMealPlan(uid, {
        'generatedAt': FieldValue.serverTimestamp(),
        'version': currentVersion,
        'generationReason': reason,
        ...planData,
      });

      await _db.collection('users').doc(uid).update({
        'lastPlanGeneratedAt': FieldValue.serverTimestamp(),
        'planVersion': currentVersion,
      });

      await _tools.pinToDashboard(uid, {
        'type': 'plan_ready',
        'message': 'Your personalized 30-day nutrition plan is ready! '
            'Tap to view your daily meal recommendations.',
        'severity': 'success',
        'foodSuggestion': null,
      });

      await _tools.logAgentAction(uid, {
        'type': 'plan_generated',
        'trigger': reason,
        'observation': 'Full 30-day plan generated',
        'decision': 'Plan v$currentVersion created',
        'action': 'saved_to_firestore',
        'outcome': 'Plan ready',
      });
    } catch (_) {
      await _saveFallbackPlan(uid, reason);
    }
  }

  Future<void> _saveFallbackPlan(String uid, String reason) async {
    final profile = await _tools.getUserProfile(uid);
    final target = (profile['dailyCalorieGoal'] ?? 2000).toInt();
    final now = DateTime.now();

    final days = <String, dynamic>{};
    for (int i = 1; i <= 30; i++) {
      final date = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: i - 1)));
      days['$i'] = {
        'date': date,
        'breakfast': _fallbackMeal('Oatmeal with fruit', 300, 8, 50, 8, 55),
        'lunch': _fallbackMeal('Grilled chicken with rice', 500, 35, 55, 15, 50),
        'dinner': _fallbackMeal('Vegetable couscous', 450, 15, 65, 12, 60),
        'snack': _fallbackMeal('Yogurt with nuts', 200, 10, 15, 10, 30),
        'dailyTotal': {'calories': 1450, 'protein': 68, 'carbs': 185, 'fats': 45},
        'theme': 'balanced day',
      };
    }

    await _tools.saveMealPlan(uid, {
      'generatedAt': FieldValue.serverTimestamp(),
      'version': 1,
      'generationReason': reason,
      'dailyCalorieTarget': target,
      'targetMacros': {
        'protein': (target * 0.25 / 4).round(),
        'carbs': (target * 0.50 / 4).round(),
        'fats': (target * 0.25 / 9).round(),
      },
      'days': days,
      'weeklyThemes': {
        'week1': 'Establishment — building the habit',
        'week2': 'Progression — increasing protein',
        'week3': 'Adaptation — variety introduced',
        'week4': 'Consolidation — refining what works',
      },
      'adaptationNotes': 'Default plan generated. Will adapt based on your behavior.',
    });

    await _tools.pinToDashboard(uid, {
      'type': 'plan_ready',
      'message': 'Your starter nutrition plan is ready! Log meals to help me personalize it.',
      'severity': 'success',
      'foodSuggestion': null,
    });
  }

  Map<String, dynamic> _fallbackMeal(
      String name, int cal, int p, int c, int f, int gi) {
    return {
      'suggestion': name,
      'portion': 200,
      'calories': cal,
      'protein': p,
      'carbs': c,
      'fats': f,
      'gi': gi,
      'recipe': 'Simple preparation with fresh ingredients.',
      'tunisianAlternative': '',
    };
  }

  Future<void> _adaptPlan(String uid, AnalysisResult analysis) async {
    // Re-generate the plan with behavior_update reason
    await generateThirtyDayPlan(uid, reason: 'behavior_update');
  }

  String _cleanJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }
    return cleaned.trim();
  }
}
