enum AgentEventType {
  mealLogged,
  morningBriefing,
  middayCheck,
  eveningSummary,
  mealReminder,
  weeklyReview,
  userMessage,
  appOpened,
  onboardingComplete,
  planUpdateRequested,
}

class AgentEvent {
  final AgentEventType type;
  final String uid;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const AgentEvent({
    required this.type,
    required this.uid,
    this.payload = const {},
    required this.timestamp,
  });

  factory AgentEvent.now({
    required AgentEventType type,
    required String uid,
    Map<String, dynamic> payload = const {},
  }) {
    return AgentEvent(
      type: type,
      uid: uid,
      payload: payload,
      timestamp: DateTime.now(),
    );
  }
}
