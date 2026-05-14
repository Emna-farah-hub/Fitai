import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../agent/agent_scheduler.dart';
import '../../../agent/core/agent_event.dart';
import '../../../agent/orchestrator.dart';
import '../../../screens/chat_screen.dart';
import '../../../screens/daily_dashboard_screen.dart';
import '../../../screens/plan_screen.dart';
import '../../../screens/shopping_list_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/fitai_bottom_nav.dart';
import 'tabs/profile_tab.dart';

/// Main dashboard screen with bottom navigation (5 tabs).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
        _kickOffAgent();
      }
    });
  }

  Future<void> _loadProfile() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    if (authProvider.currentUser != null && !userProvider.hasProfile) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }
  }

  /// Fires AgentEventType.appOpened so the orchestrator can post a morning
  /// briefing or meal suggestion if the time-of-day calls for it, and ensures
  /// the recurring AgentScheduler is running for this user.
  void _kickOffAgent() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    AgentScheduler().start(uid);
    unawaited(
      AgentOrchestrator().handle(
        AgentEvent.now(type: AgentEventType.appOpened, uid: uid),
      ),
    );
  }

  static const List<FitAINavTab> _navTabs = [
    FitAINavTab(icon: Icons.menu_book_outlined, label: 'Journal'),
    FitAINavTab(icon: Icons.calendar_today_outlined, label: 'Your Plan'),
    FitAINavTab(icon: Icons.auto_awesome_outlined, label: 'AI Chat'),
    FitAINavTab(icon: Icons.shopping_cart_outlined, label: 'Groceries'),
    FitAINavTab(icon: Icons.edit_outlined, label: 'Edit'),
  ];

  // IndexedStack preserves each tab's scroll state so switching feels instant.
  // Order maps 1:1 with [_navTabs].
  static const List<Widget> _tabs = [
    DailyDashboardScreen(), // Journal: today's macros + meals + manual + entry
    PlanScreen(),            // Your Plan: 7-day plan, "I ate this" auto-logs
    ChatScreen(),            // AI Chat
    ShoppingListScreen(),    // Groceries
    ProfileTab(),            // Edit profile / settings
  ];

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: FitAIBottomNav(
        tabs: _navTabs,
        currentIndex: _selectedIndex,
        onTabSelected: _onTabTapped,
      ),
    );
  }
}
