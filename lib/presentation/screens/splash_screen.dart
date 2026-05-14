import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

/// Initial splash screen shown on app launch.
/// Checks auth state and routes accordingly:
///   - Not logged in → /login
///   - Logged in, onboarding incomplete → /onboarding
///   - Logged in, onboarding complete → /dashboard
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _profileLoadTimeout = Duration(seconds: 6);

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Wait for the splash animation
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    debugPrint('[SPLASH] isAuthenticated=${authProvider.isAuthenticated}');

    if (!authProvider.isAuthenticated) {
      debugPrint('[SPLASH] → /welcome');
      context.go('/welcome');
      return;
    }

    final uid = authProvider.currentUser!.uid;
    final prefs = await SharedPreferences.getInstance();
    final localOnboardingComplete =
        prefs.getBool('onboardingComplete_$uid') ??
        prefs.getBool('onboardingComplete') ??
        false;

    // Load the user profile to check onboarding status.
    // Never block the splash forever on a slow Firestore read.
    try {
      await userProvider.loadProfile(uid).timeout(_profileLoadTimeout);
    } catch (e) {
      debugPrint('[SPLASH] profile load timed out/failed: $e');
    }
    if (!mounted) return;

    debugPrint(
      '[SPLASH] onboardingComplete=${userProvider.onboardingComplete}, '
      'localOnboardingComplete=$localOnboardingComplete, '
      'error=${userProvider.errorMessage}, '
      'hasProfile=${userProvider.hasProfile}',
    );

    final onboardingComplete =
        userProvider.onboardingComplete || localOnboardingComplete;

    if (!onboardingComplete) {
      debugPrint('[SPLASH] → /onboarding');
      context.go('/onboarding');
      return;
    }

    debugPrint('[SPLASH] → /dashboard');
    context.go('/dashboard');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(scale: _scaleAnimation, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                Text(
                  'FitAI',
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Text(
                  'Your AI-powered nutrition coach',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading indicator
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
