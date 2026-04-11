import 'dart:async';
import 'package:intl/intl.dart';
import 'core/agent_event.dart';
import 'orchestrator.dart';

/// Periodically checks if scheduled agent events should fire.
/// Uses Timer.periodic every 30 minutes.
class AgentScheduler {
  Timer? _timer;
  String? _uid;
  final AgentOrchestrator _orchestrator = AgentOrchestrator();

  // Track which events have already fired today
  final Map<String, bool> _firedToday = {};
  String _lastDateKey = '';

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _hasFired(String key) => _firedToday['${_todayKey}_$key'] == true;

  void _markFired(String key) => _firedToday['${_todayKey}_$key'] = true;

  /// Starts the scheduler for a given user.
  void start(String uid) {
    _uid = uid;
    _timer?.cancel();

    // Check immediately on start
    _check();

    // Then every 30 minutes
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check());
  }

  /// Stops the scheduler.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _uid = null;
  }

  void _check() {
    final uid = _uid;
    if (uid == null) return;

    // Reset flags on new day
    if (_todayKey != _lastDateKey) {
      _firedToday.clear();
      _lastDateKey = _todayKey;
    }

    final hour = DateTime.now().hour;
    final weekday = DateTime.now().weekday; // 7 = Sunday

    // 8 AM → morning briefing
    if (hour >= 8 && hour < 10 && !_hasFired('morning')) {
      _markFired('morning');
      _orchestrator.handle(AgentEvent.now(
        type: AgentEventType.morningBriefing,
        uid: uid,
      ));
    }

    // 12 PM → midday check
    if (hour >= 12 && hour < 14 && !_hasFired('midday')) {
      _markFired('midday');
      _orchestrator.handle(AgentEvent.now(
        type: AgentEventType.middayCheck,
        uid: uid,
      ));
    }

    // 8 PM → evening summary
    if (hour >= 20 && hour < 22 && !_hasFired('evening')) {
      _markFired('evening');
      _orchestrator.handle(AgentEvent.now(
        type: AgentEventType.eveningSummary,
        uid: uid,
      ));
    }

    // Sunday 9 PM → weekly review
    if (weekday == 7 && hour >= 21 && !_hasFired('weekly')) {
      _markFired('weekly');
      _orchestrator.handle(AgentEvent.now(
        type: AgentEventType.weeklyReview,
        uid: uid,
      ));
    }

    // Every 3 hours with no meal → meal reminder
    // (Checked based on hour blocks: 9, 12, 15, 18)
    final reminderBlock = '${hour ~/ 3}';
    if (hour >= 9 && hour <= 20 && !_hasFired('reminder_$reminderBlock')) {
      _markFired('reminder_$reminderBlock');
      _orchestrator.handle(AgentEvent.now(
        type: AgentEventType.mealReminder,
        uid: uid,
      ));
    }
  }
}
