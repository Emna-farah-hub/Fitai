import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../tools/agent_tools.dart';

/// Analysis result from the Analyst Agent.
class AnalysisResult {
  final String status; // on_track, under_eating, over_eating, protein_low, glycemic_risk, skipping_meals
  final String summary;
  final List<String> gaps;
  final List<String> risks;
  final String priority;
  final String suggestedAction;
  final String behaviorPattern;
  final bool planAdjustmentNeeded;

  const AnalysisResult({
    required this.status,
    required this.summary,
    required this.gaps,
    required this.risks,
    required this.priority,
    required this.suggestedAction,
    required this.behaviorPattern,
    required this.planAdjustmentNeeded,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      status: json['status'] ?? 'on_track',
      summary: json['summary'] ?? '',
      gaps: List<String>.from(json['gaps'] ?? []),
      risks: List<String>.from(json['risks'] ?? []),
      priority: json['priority'] ?? '',
      suggestedAction: json['suggestedAction'] ?? '',
      behaviorPattern: json['behaviorPattern'] ?? '',
      planAdjustmentNeeded: json['planAdjustmentNeeded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'summary': summary,
        'gaps': gaps,
        'risks': risks,
        'priority': priority,
        'suggestedAction': suggestedAction,
        'behaviorPattern': behaviorPattern,
        'planAdjustmentNeeded': planAdjustmentNeeded,
      };

  static AnalysisResult fallback() => const AnalysisResult(
        status: 'on_track',
        summary: 'Unable to analyze right now. Keep logging your meals!',
        gaps: [],
        risks: [],
        priority: 'Keep logging meals consistently',
        suggestedAction: 'Continue with your current plan',
        behaviorPattern: 'Insufficient data',
        planAdjustmentNeeded: false,
      );
}

/// The Analyst Agent: reads data, finds patterns, returns JSON.
/// Never talks to the user. Never gives advice.
class AnalystAgent {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  final AgentTools _tools = AgentTools();
  GenerativeModel? _model;

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.text(
        'You are a nutrition data analyst. You ONLY produce structured JSON analysis. '
        'You NEVER talk to the user. You NEVER give advice. '
        'You read nutritional data and find patterns. '
        'Always respond with valid JSON only — no markdown, no explanation.',
      ),
    );
    return _model!;
  }

  /// Runs full analysis for a user.
  Future<AnalysisResult> analyze(String uid) async {
    if (_apiKey.isEmpty) return AnalysisResult.fallback();

    try {
      final profile = await _tools.getUserProfile(uid);
      final dailyLog = await _tools.analyzeDailyLog(uid);
      final weeklyHistory = await _tools.getWeeklyHistory(uid);

      final prompt = '''
Analyze this user's nutritional data and return a JSON object.

USER PROFILE:
${jsonEncode(profile)}

TODAY'S LOG:
${jsonEncode(dailyLog)}

WEEKLY HISTORY:
${jsonEncode(weeklyHistory)}

Return ONLY this JSON structure (no markdown fences):
{
  "status": "on_track" | "under_eating" | "over_eating" | "protein_low" | "glycemic_risk" | "skipping_meals",
  "summary": "one sentence summary of current state",
  "gaps": ["list of nutritional gaps"],
  "risks": ["list of health risks"],
  "priority": "what the user needs most right now",
  "suggestedAction": "what should happen next",
  "behaviorPattern": "pattern observed over 7 days",
  "planAdjustmentNeeded": true or false
}
''';

      final response = await _gemini.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final cleaned = _cleanJson(text);
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (_) {
      return AnalysisResult.fallback();
    }
  }

  String _cleanJson(String text) {
    var cleaned = text.trim();
    // Remove markdown code fences
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }
    return cleaned.trim();
  }
}
