import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/firebase_auth_service.dart';
import 'data/services/firestore_service.dart';
import 'firebase_options.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/onboarding_provider.dart';
import 'presentation/providers/user_provider.dart';
import 'services/food_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await seedAllFoods();

  runApp(const FitAIApp());
}

class FitAIApp extends StatelessWidget {
  const FitAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Service singletons wired up here; repositories get injected into providers
    final authService = FirebaseAuthService();
    final firestoreService = FirestoreService();
    final authRepository = AuthRepository(
      authService: authService,
      firestoreService: firestoreService,
    );
    final userRepository = UserRepository(firestoreService: firestoreService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(userRepository: userRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingProvider(userRepository: userRepository),
        ),
      ],
      child: const _RouterApp(),
    );
  }
}

/// Separated widget so GoRouter can be created with access to the Provider context.
class _RouterApp extends StatefulWidget {
  const _RouterApp();

  @override
  State<_RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<_RouterApp> {
  late final _router = AppRouter.createRouter(context);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FitAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
