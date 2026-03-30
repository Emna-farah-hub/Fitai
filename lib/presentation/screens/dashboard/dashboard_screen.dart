import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'tabs/home_tab.dart';
import 'tabs/placeholder_tab.dart';

/// Main dashboard screen with bottom navigation (5 tabs).
/// Only the Home tab is built in Sprint 1; others are placeholders.
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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    if (authProvider.currentUser != null && !userProvider.hasProfile) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeTab(),
      const PlaceholderTab(
        icon: Icons.restaurant_menu_outlined,
        label: 'Log Meal',
        description: 'AI-powered meal logging coming in Sprint 2',
      ),
      const PlaceholderTab(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'AI Chat',
        description: 'Chat with your AI nutrition coach — coming soon',
      ),
      const PlaceholderTab(
        icon: Icons.bar_chart_rounded,
        label: 'History',
        description: 'Your nutrition history and trends — coming soon',
      ),
      const PlaceholderTab(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        description: 'Manage your profile and settings — coming soon',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Log Meal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
