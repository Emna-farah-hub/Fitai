import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/api_key.dart';
import '../tools/agent_tools.dart';
import 'analyst_agent.dart';

/// Suggestion card returned by the coach for meal recommendations.
class SuggestionCard {
  final String foodName;
  final double portion;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final int gi;
  final String whySuggested;
  final String quickPreparationTip;
  final String alternativeOption;

  const SuggestionCard({
    required this.foodName,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.gi,
    required this.whySuggested,
    required this.quickPreparationTip,
    required this.alternativeOption,
  });

  factory SuggestionCard.fromJson(Map<String, dynamic> json) {
    return SuggestionCard(
      foodName: json['foodName'] ?? '',
      portion: (json['portion'] ?? 100).toDouble(),
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fats: (json['fats'] ?? 0).toDouble(),
      gi: (json['gi'] ?? 0).toInt(),
      whySuggested: json['whySuggested'] ?? '',
      quickPreparationTip: json['quickPreparationTip'] ?? '',
      alternativeOption: json['alternativeOption'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'portion': portion,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'gi': gi,
        'whySuggested': whySuggested,
        'quickPreparationTip': quickPreparationTip,
        'alternativeOption': alternativeOption,
      };
}

/// The Coach Agent: translates analysis into warm, specific messages.
/// Has function calling with search_food_db tool.
class CoachAgent {
  static const _apiKey = ApiKeys.geminiApiKey;
  final AgentTools _tools = AgentTools();
  GenerativeModel? _model;

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      tools: [
        Tool(functionDeclarations: [
          FunctionDeclaration(
            'search_food_db',
            'Search the local food database for a food item by name. Returns nutrition data.',
            Schema(SchemaType.object, properties: {
              'query': Schema(SchemaType.string,
                  description: 'Food name to search for'),
            }, requiredProperties: [
              'query'
            ]),
          ),
        ]),
      ],
      systemInstruction: Content.text(
        'You are a warm personal nutrition coach for a Tunisian user. '
        'You receive analysis data — translate it into short specific actionable messages. '
        'Maximum 3 sentences per message. '
        'Always mention a specific food by name. '
        'If the user is diabetic always mention glycemic impact. '
        'Never be generic — always reference the user\'s actual data and food preferences. '
        'Use the user\'s name in morning messages. '
        'Call search_food_db() whenever you want to suggest a food to validate it exists. '
        'When suggesting Tunisian foods, prefer local dishes the user likes.',
      ),
    );
    return _model!;
  }

  /// Generates a coaching message from analysis and profile.
  Future<String> generateMessage({
    required AnalysisResult analysis,
    required Map<String, dynamic> profile,
    String context = '',
  }) async {
    if (_apiKey.isEmpty) {
      return _fallbackMessage(analysis);
    }

    try {
      final prompt =
          'Analysis: ${jsonEncode(analysis.toJson())}\n'
          'Profile: ${jsonEncode(profile)}\n'
          'Context: $context\n\n'
          'Generate a short, warm coaching message (max 3 sentences). '
          'Be specific — mention actual foods and numbers.';

      final chat = _gemini.startChat();
      var response = await chat.sendMessage(Content.text(prompt));

      // ReAct loop: handle function calls
      while (response.candidates.isNotEmpty &&
          response.candidates.first.content.parts.any((p) => p is FunctionCall)) {
        final functionCalls = response.candidates.first.content.parts
            .whereType<FunctionCall>()
            .toList();

        final functionResponses = <FunctionResponse>[];
        for (final call in functionCalls) {
          if (call.name == 'search_food_db') {
            final query = call.args['query'] as String? ?? '';
            final result = await _tools.searchFoodDb(query);
            functionResponses.add(FunctionResponse(call.name, result));
          }
        }

        response = await chat.sendMessage(
          Content.functionResponses(functionResponses),
        );
      }

      return response.text ?? _fallbackMessage(analysis);
    } catch (_) {
      return _fallbackMessage(analysis);
    }
  }

  /// Generates a specific meal suggestion.
  Future<SuggestionCard> generateMealSuggestion(
      String uid, String mealType) async {
    if (_apiKey.isEmpty) return _fallbackSuggestion(mealType);

    try {
      final profile = await _tools.getUserProfile(uid);
      final dailyLog = await _tools.analyzeDailyLog(uid);
      final agentProfile =
          profile['agentProfile'] as Map<String, dynamic>? ?? {};

      final remainingCal =
          (profile['dailyCalorieGoal'] ?? 2000) - (dailyLog['totalCalories'] ?? 0);

      final prompt =
          'Generate a specific meal suggestion for $mealType.\n\n'
          'User profile: ${jsonEncode(profile)}\n'
          'Agent profile (preferences): ${jsonEncode(agentProfile)}\n'
          'Today\'s log so far: ${jsonEncode(dailyLog)}\n'
          'Remaining calories: $remainingCal\n\n'
          'Requirements:\n'
          '- Respect user\'s preferred foods: ${agentProfile['preferredFoods'] ?? 'not set'}\n'
          '- Avoid: ${agentProfile['avoidedFoods'] ?? 'nothing'}\n'
          '- Cooking level: ${agentProfile['cookingLevel'] ?? 'basic'}\n'
          '- Budget: ${agentProfile['budget'] ?? 'medium'}\n'
          '- Do NOT repeat foods already eaten today\n'
          '- Call search_food_db() to validate your suggestion exists\n\n'
          'Respond with ONLY this JSON (no markdown fences):\n'
          '{"foodName":"...","portion":grams,"calories":num,"protein":num,'
          '"carbs":num,"fats":num,"gi":num,"whySuggested":"one sentence",'
          '"quickPreparationTip":"one sentence","alternativeOption":"food name"}';

      final chat = _gemini.startChat();
      var response = await chat.sendMessage(Content.text(prompt));

      // ReAct loop
      while (response.candidates.isNotEmpty &&
          response.candidates.first.content.parts.any((p) => p is FunctionCall)) {
        final functionCalls = response.candidates.first.content.parts
            .whereType<FunctionCall>()
            .toList();

        final functionResponses = <FunctionResponse>[];
        for (final call in functionCalls) {
          if (call.name == 'search_food_db') {
            final query = call.args['query'] as String? ?? '';
            final result = await _tools.searchFoodDb(query);
            functionResponses.add(FunctionResponse(call.name, result));
          }
        }

        response = await chat.sendMessage(
          Content.functionResponses(functionResponses),
        );
      }

      final text = response.text ?? '';
      final cleaned = _cleanJson(text);
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return SuggestionCard.fromJson(json);
    } catch (_) {
      return _fallbackSuggestion(mealType);
    }
  }

  String _fallbackMessage(AnalysisResult analysis) {
    if (analysis.status == 'under_eating') {
      return "You're eating less than your target today. Try adding a balanced snack like yogurt with fruit to boost your intake.";
    }
    if (analysis.status == 'over_eating') {
      return "You've gone a bit over your calorie target. For your next meal, try a lighter option like a salad with grilled chicken.";
    }
    if (analysis.status == 'protein_low') {
      return "Your protein is running low today. Consider adding eggs, Greek yogurt, or grilled chicken to your next meal.";
    }
    return "You're doing well today! Keep logging your meals to stay on track with your nutrition goals.";
  }

  SuggestionCard _fallbackSuggestion(String mealType) {
    final suggestions = {
      'Breakfast': const SuggestionCard(
        foodName: 'Oatmeal with banana',
        portion: 250,
        calories: 300,
        protein: 8,
        carbs: 55,
        fats: 6,
        gi: 55,
        whySuggested: 'A balanced breakfast to start your day with sustained energy.',
        quickPreparationTip: 'Cook oats with milk, top with sliced banana and a drizzle of honey.',
        alternativeOption: 'Whole wheat toast with eggs',
      ),
      'Lunch': const SuggestionCard(
        foodName: 'Grilled chicken salad',
        portion: 350,
        calories: 420,
        protein: 35,
        carbs: 20,
        fats: 18,
        gi: 35,
        whySuggested: 'High protein, low GI lunch to keep you full and focused.',
        quickPreparationTip: 'Grill chicken breast, serve over mixed greens with olive oil dressing.',
        alternativeOption: 'Tuna sandwich on whole wheat',
      ),
      'Dinner': const SuggestionCard(
        foodName: 'Couscous with vegetables',
        portion: 300,
        calories: 380,
        protein: 12,
        carbs: 60,
        fats: 10,
        gi: 65,
        whySuggested: 'A traditional Tunisian dinner that balances carbs and nutrients.',
        quickPreparationTip: 'Steam couscous, serve with mixed roasted vegetables and chickpeas.',
        alternativeOption: 'Grilled fish with rice',
      ),
      'Snack': const SuggestionCard(
        foodName: 'Greek yogurt with almonds',
        portion: 200,
        calories: 180,
        protein: 15,
        carbs: 12,
        fats: 8,
        gi: 25,
        whySuggested: 'A protein-rich snack to bridge the gap between meals.',
        quickPreparationTip: 'Add a handful of almonds to plain Greek yogurt.',
        alternativeOption: 'Apple with peanut butter',
      ),
    };
    return suggestions[mealType] ?? suggestions['Lunch']!;
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
