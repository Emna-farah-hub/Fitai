import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/user_provider.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../screens/agent_onboarding_screen.dart';
import '../../screens/chat_screen.dart';
import '../../screens/plan_screen.dart';

/// GoRouter configuration for FitAI.
///
/// Route structure:
///   /splash      → SplashScreen (entry point)
///   /login       → LoginScreen
///   /register    → RegisterScreen
///   /onboarding  → OnboardingScreen
///   /dashboard   → DashboardScreen
///
/// Guards:
///   - Unauthenticated users are redirected to /login
///   - Authenticated users without completed onboarding go to /onboarding
class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        final isSplash = state.matchedLocation == '/splash';

        debugPrint('[ROUTER] redirect: path=${state.matchedLocation}, '
            'isLoggedIn=$isLoggedIn, isAuthRoute=$isAuthRoute, '
            'onboardingComplete=${userProvider.onboardingComplete}');

        // Always allow splash screen to run its own routing logic
        if (isSplash) return null;

        // Not logged in → force to login
        if (!isLoggedIn && !isAuthRoute) return '/login';

        // Logged in trying to access auth screens → go to appropriate screen
        if (isLoggedIn && isAuthRoute) {
          if (!userProvider.onboardingComplete) return '/onboarding';
          return '/dashboard';
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/agent-onboarding',
          builder: (context, state) => const AgentOnboardingScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: '/plan',
          builder: (context, state) => const PlanScreen(),
        ),
      ],
    );
  }
}
