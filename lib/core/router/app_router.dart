import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/user_provider.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/welcome_screen.dart';
import '../../presentation/screens/onboarding/onboarding_flow_controller.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../screens/agent_onboarding_screen.dart';
import '../../screens/chat_screen.dart';
import '../../screens/plan_screen.dart';
import '../../screens/shopping_list_screen.dart';
import '../../screens/swipe_screen.dart';

/// GoRouter configuration for FitAI.
///
/// Route structure:
///   /splash      → SplashScreen (entry point)
///   /welcome     → WelcomeScreen (sage-green intro after splash)
///   /login       → LoginScreen
///   /register    → RegisterScreen
///   /onboarding  → OnboardingFlowController
///   /dashboard   → DashboardScreen
///
/// Guards:
///   - Unauthenticated users on protected routes are redirected to /welcome
///   - Authenticated users hitting /welcome or auth screens are routed to
///     /onboarding (if incomplete) or /dashboard
class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final isAuthRoute =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        final isSplash = state.matchedLocation == '/splash';
        final isWelcome = state.matchedLocation == '/welcome';

        debugPrint(
          '[ROUTER] redirect: path=${state.matchedLocation}, '
          'isLoggedIn=$isLoggedIn, isAuthRoute=$isAuthRoute, '
          'onboardingComplete=${userProvider.onboardingComplete}',
        );

        // Always allow splash screen to run its own routing logic
        if (isSplash) return null;

        // Not logged in → allow welcome/login/register, otherwise → /welcome
        if (!isLoggedIn && !isAuthRoute && !isWelcome) return '/welcome';

        // Logged in trying to access welcome/auth screens → go to appropriate screen
        if (isLoggedIn && (isAuthRoute || isWelcome)) {
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
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
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
          builder: (context, state) => const OnboardingFlowController(),
        ),
        GoRoute(
          path: '/agent-onboarding',
          builder: (context, state) => const AgentOnboardingScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
        GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
        GoRoute(
          path: '/groceries',
          builder: (context, state) => const ShoppingListScreen(),
        ),
        GoRoute(
          path: '/swipe',
          builder: (context, state) {
            final isOnboarding = state.extra as bool? ?? false;
            return SwipeScreen(
              isOnboarding: isOnboarding,
              onComplete: isOnboarding
                  ? () {
                      if (context.mounted) context.go('/dashboard');
                    }
                  : null,
            );
          },
        ),
      ],
    );
  }
}
