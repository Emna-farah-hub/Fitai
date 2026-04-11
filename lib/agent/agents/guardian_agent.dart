import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_entry.dart';
import '../tools/agent_tools.dart';
import 'coach_agent.dart';
import 'analyst_agent.dart';

/// The Guardian Agent: pure logic, no Gemini. Monitors glycemic safety.
class GuardianAgent {
  final AgentTools _tools = AgentTools();
  final CoachAgent _coach = CoachAgent();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Checks a newly logged meal for glycemic risk.
  /// Only acts if the user is diabetic.
  Future<void> checkMeal(MealEntry meal, String uid) async {
    try {
      final profile = await _tools.getUserProfile(uid);
      if (!profile['found']) return;

      final goals = List<String>.from(profile['goals'] ?? []);
      final conditions = List<String>.from(profile['conditions'] ?? []);
      final isDiabetic =
          goals.any((g) => g.toLowerCase().contains('diabetes')) ||
          conditions.any((c) => c.toLowerCase().contains('diabetes'));

      if (!isDiabetic) return;

      // Calculate glycemic classification
      final gi = meal.glycemicIndex;
      String glycemicLevel;
      if (gi <= 55) {
        glycemicLevel = 'green';
      } else if (gi <= 69) {
        glycemicLevel = 'orange';
      } else {
        glycemicLevel = 'red';
      }

      // Update meal document with glycemic score
      await _db
          .collection('meals')
          .doc(uid)
          .collection('logs')
          .doc(meal.date)
          .collection('entries')
          .doc(meal.id)
          .update({'glycemicScore': glycemicLevel});

      // Update daily glycemic aggregate
      await _updateDailyGlycemic(uid, meal.date);

      // If RED: generate alert
      if (glycemicLevel == 'red') {
        final analysis = AnalysisResult(
          status: 'glycemic_risk',
          summary:
              '${meal.foodName} has a high glycemic index of $gi.',
          gaps: [],
          risks: ['High GI food logged: ${meal.foodName} (GI: $gi)'],
          priority: 'Glycemic management',
          suggestedAction: 'Suggest a low-GI alternative',
          behaviorPattern: '',
          planAdjustmentNeeded: false,
        );

        final message = await _coach.generateMessage(
          analysis: analysis,
          profile: profile,
          context: 'glycemic_risk: User just ate ${meal.foodName} with GI $gi',
        );

        await _tools.pinToDashboard(uid, {
          'type': 'glycemic_alert',
          'message': message,
          'severity': 'warning',
          'foodSuggestion': null,
        });

        await _tools.logAgentAction(uid, {
          'type': 'glycemic_alert',
          'trigger': 'meal_logged',
          'observation': 'High GI food: ${meal.foodName} (GI: $gi)',
          'decision': 'Alert user about glycemic risk',
          'action': 'pinned_warning',
          'outcome': 'Dashboard alert created',
        });
      }
    } catch (_) {
      // Guardian never crashes — silently handle errors
    }
  }

  Future<void> _updateDailyGlycemic(String uid, String date) async {
    try {
      final snap = await _db
          .collection('meals')
          .doc(uid)
          .collection('logs')
          .doc(date)
          .collection('entries')
          .get();

      double totalGI = 0;
      int count = 0;
      for (final doc in snap.docs) {
        final gi = (doc.data()['glycemicIndex'] ?? 0).toInt();
        if (gi > 0) {
          totalGI += gi;
          count++;
        }
      }

      if (count > 0) {
        await _db
            .collection('meals')
            .doc(uid)
            .collection('logs')
            .doc(date)
            .set({
          'averageGI': totalGI / count,
          'mealCount': count,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
