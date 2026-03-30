/// All user-facing string constants for the FitAI app.
/// Centralizing strings makes future localization straightforward.
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'FitAI';
  static const String appTagline = 'Your AI-powered nutrition coach';

  // Splash
  static const String getStarted = 'Get Started';

  // Auth
  static const String login = 'Log In';
  static const String register = 'Create Account';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String noAccount = "Don't have an account? Sign up";
  static const String hasAccount = 'Already have an account? Log in';
  static const String signOut = 'Sign Out';

  // Onboarding steps
  static const List<String> onboardingTitles = [
    'Welcome to FitAI!',
    "What's your name?",
    'When were you born?',
    'How tall are you?',
    'What\'s your current weight?',
    'What\'s your biological sex?',
    'How active are you?',
    'What\'s your fitness level?',
    'Any health conditions?',
    'What are your goals?',
    'Any dietary preferences?',
    'Building your plan...',
  ];

  static const List<String> onboardingSubtitles = [
    'Your personal AI nutrition coach for a healthier you.',
    "I'll use your name to personalize your experience.",
    "I'll use this to calculate your nutritional needs accurately.",
    "I'll calculate your ideal calorie intake based on your body.",
    "This helps me set your starting baseline.",
    "Metabolism differs — this helps me calculate more accurately.",
    "Your activity level is key to calculating your daily calorie burn.",
    "Be honest — this helps me suggest the right intensity.",
    "This lets me tailor your nutrition plan to your health needs.",
    "Choose all that apply — your plan is built around these.",
    "I'll suggest meals that match your eating style.",
    "Analyzing your data and crafting your personalized nutrition plan...",
  ];

  // Activity Levels
  static const String sedentary = 'Sedentary';
  static const String lightlyActive = 'Lightly Active';
  static const String moderatelyActive = 'Moderately Active';
  static const String veryActive = 'Very Active';

  // Fitness Levels
  static const List<String> fitnessLevels = [
    'Just starting out',
    'Getting there',
    'Moderately fit',
    'Very fit',
    'Super powerful',
  ];

  // Health Conditions
  static const List<String> healthConditions = [
    'None',
    'Diabetes Type 1',
    'Diabetes Type 2',
    'Hypertension',
    'High Cholesterol',
  ];

  // Goals
  static const List<String> goals = [
    'Lose Weight',
    'Maintain Weight',
    'Build Muscle',
    'Track Glycemic Index',
    'Improve Energy',
  ];

  // Dietary Preferences
  static const List<String> dietaryPreferences = [
    'Classic',
    'Vegan',
    'Vegetarian',
    'Keto',
    'Mediterranean',
    'Gluten-Free',
    'Dairy-Free',
  ];

  // Sex options
  static const String male = 'Male';
  static const String female = 'Female';

  // Navigation
  static const String home = 'Home';
  static const String logMeal = 'Log Meal';
  static const String aiChat = 'AI Chat';
  static const String history = 'History';
  static const String profile = 'Profile';

  // Dashboard
  static const String dailyCalories = 'Daily Calorie Goal';
  static const String bmr = 'BMR';
  static const String tdee = 'TDEE';
  static const String yourGoals = 'Your Goals';

  // Errors
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorInvalidEmail = 'Please enter a valid email address.';
  static const String errorWeakPassword = 'Password must be at least 6 characters.';
  static const String errorPasswordMismatch = 'Passwords do not match.';
  static const String errorUserNotFound = 'No account found with this email.';
  static const String errorWrongPassword = 'Incorrect password. Please try again.';
  static const String errorEmailInUse = 'An account already exists with this email.';
  static const String errorNetworkRequest = 'Network error. Check your connection.';
}
