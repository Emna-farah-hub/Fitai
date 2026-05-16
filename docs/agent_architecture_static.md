# FitAI Agent System - Architecture Document

This document is a static map of the current FitAI agent system and adjacent AI/personalization subsystems as implemented in the codebase.

## 1. Scope and System Boundary

Included:
- Core runtime agents in [lib/agent](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent>)
- Agent entry points from screens and services
- Shared tool, scoring, journaling, planning, and swipe-personalization services
- Firestore collections and asset data stores used by those systems
- External APIs and frameworks used by the agent runtime

Excluded from detailed behavioral mapping:
- Pure UI-only screens with no agent trigger/output role
- Authentication and profile CRUD internals beyond their role as upstream data providers

## 2. Component Inventory

### A. Runtime Agents

- `AgentScheduler`
  - File: [lib/agent/agent_scheduler.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agent_scheduler.dart:8>)
  - Role: time-based event source; emits scheduled `AgentEvent`s.

- `AgentOrchestrator`
  - File: [lib/agent/orchestrator.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/orchestrator.dart:14>)
  - Role: singleton supervisor/router for all agent events and plan actions.

- `AnalystAgent`
  - File: [lib/agent/agents/analyst_agent.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agents/analyst_agent.dart:65>)
  - Role: Gemini-based structured nutrition analysis.

- `CoachAgent`
  - File: [lib/agent/agents/coach_agent.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agents/coach_agent.dart:64>)
  - Role: Gemini-based user-facing coaching text and function-calling food lookup.

- `GuardianAgent`
  - File: [lib/agent/agents/guardian_agent.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agents/guardian_agent.dart:8>)
  - Role: rule-based glycemic safety monitor for logged meals.

### B. Supporting Services Used by the Agent System

- `AgentTools`
  - File: [lib/agent/tools/agent_tools.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/tools/agent_tools.dart:6>)
  - Role: Firestore read/write tool layer shared by all agents.

- `FoodScoringService`
  - File: [lib/services/food_scoring_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/food_scoring_service.dart:50>)
  - Role: deterministic goal-safety, ranking, learned preference scoring, weekly learning.

- `MealJournalService`
  - File: [lib/services/meal_journal_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/meal_journal_service.dart:13>)
  - Role: persists meal diary entries and emits `mealLogged` events.

- `StreakService`
  - File: [lib/services/streak_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/streak_service.dart>)
  - Role: side-effect service called after meal logging; not part of agent reasoning but part of the same meal-log flow.

### C. Adjacent AI/Personalization Subsystem

This subsystem is important architecturally, but it is not currently wired into the `/agent` runtime.

- `MealCatalogService`
  - File: [lib/services/meal_catalog_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/meal_catalog_service.dart:11>)
  - Role: loads `assets/production_meals_v2.json`, applies Firestore image overrides, exposes filtered meal catalog.

- `SwipePersonalizationService`
  - File: [lib/services/swipe_personalization_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/swipe_personalization_service.dart:14>)
  - Role: builds and persists personalized 15-card swipe batches.

- `Meal`
  - File: [lib/models/meal.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/models/meal.dart:3>)
  - Role: unified meal model used by swipe/catalog/personalization.

### D. Triggering Screens / Entry Points

- `DashboardScreen`
  - File: [lib/presentation/screens/dashboard/dashboard_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/dashboard/dashboard_screen.dart:17>)
  - Role: starts scheduler and emits `appOpened`.

- `OnboardingFlowController`
  - File: [lib/presentation/screens/onboarding/onboarding_flow_controller.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/onboarding/onboarding_flow_controller.dart:1>)
  - Role: emits `onboardingComplete` after main onboarding.

- `AgentOnboardingScreen`
  - File: [lib/screens/agent_onboarding_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/agent_onboarding_screen.dart:15>)
  - Role: alternate deeper onboarding; emits `onboardingComplete` after swipe completion.

- `ChatScreen`
  - File: [lib/screens/chat_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/chat_screen.dart:18>)
  - Role: writes user chat messages and emits `userMessage`.

- `PlanScreen`
  - File: [lib/screens/plan_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/plan_screen.dart:15>)
  - Role: consumes meal plans and directly invokes orchestrator plan actions.

- `SwipeScreen`
  - File: [lib/screens/swipe_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/swipe_screen.dart:14>)
  - Role: consumes `SwipePersonalizationService`; not part of `/agent` runtime.

- `DailyDashboardScreen`
  - File: [lib/screens/daily_dashboard_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/daily_dashboard_screen.dart:1>)
  - Role: renders `dashboard_pins/{uid}` and meal suggestions produced by the orchestrator.

### E. Upstream Profile / App Infrastructure

- `OnboardingProvider`
  - File: [lib/presentation/providers/onboarding_provider.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/providers/onboarding_provider.dart:7>)
  - Role: builds and saves user profile fields consumed later by agents.

- `UserProvider`
  - File: [lib/presentation/providers/user_provider.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/providers/user_provider.dart:6>)
  - Role: holds loaded profile in memory for route gating/UI.

- `AppRouter`
  - File: [lib/core/router/app_router.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/core/router/app_router.dart:16>)
  - Role: routes users into onboarding/dashboard/chat/plan entry points.

- `PushNotificationService`
  - File: [lib/data/services/push_notification_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/data/services/push_notification_service.dart:24>)
  - Role: receives FCM and stores FCM token; not directly invoked by agents today.

- `FoodSeeder`
  - File: [lib/services/food_seeder.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/food_seeder.dart:7>)
  - Role: seeds `common_foods`, `tunisian_foods`, and `tunisian_meals` collections for agent lookup/planning.

### F. Databases / Persistent Stores

- Firestore collections
  - `users`
  - `meals/{uid}/logs/{date}/entries`
  - `dashboard_pins`
  - `meal_plan`
  - `preferences`
  - `chat/{uid}/messages`
  - `agent_actions/{uid}/log`
  - `meal_recommendations/{uid}/events`
  - `tunisian_foods`
  - `common_foods`
  - `tunisian_meals`
  - `config/mealImages`
  - `users/{uid}/swipeState/current`

- Local asset stores
  - `assets/common_foods.json`
  - `assets/Tunisian_meals.json`
  - `assets/production_meals_v2.json`

### G. External APIs / Frameworks

- Google Gemini via `google_generative_ai`
  - Used by `AnalystAgent` and `CoachAgent`
- Firebase Firestore
  - Primary application database and shared state store
- Firebase Authentication
  - Provides current user identity used by all agent entry points
- Firebase Cloud Messaging
  - Token/notification infrastructure; not yet used as an agent output channel

## 3. Shared State, Config, and Resources

### Shared Firestore State

- `users/{uid}`
  - Shared by: onboarding, dashboard, orchestrator, analyst, coach, guardian, swipe personalization
  - Carries: demographic profile, goals, conditions, calorie target, `agentProfile`, FCM token

- `preferences/{uid}`
  - Shared by: `FoodScoringService`, `SwipePersonalizationService`, weekly insights, swipe UI
  - Carries: `tagScores`, swipe history, liked/disliked IDs, ingredient/cuisine/macro/mealType preferences

- `meal_plan/{uid}`
  - Shared by: `AgentOrchestrator`, `PlanScreen`, weekly insights, shopping list
  - Carries: 7-day plan, day slots, `confirmed`, `swapped`, versioning, generation metadata

- `dashboard_pins/{uid}`
  - Shared by: orchestrator/guardian write path, dashboard read path
  - Important behavior: single-document last-write-wins pin model

- `chat/{uid}/messages`
  - Shared by: `ChatScreen`, orchestrator

- `tunisian_meals`
  - Shared by: `FoodSeeder`, `AgentOrchestrator`

- `config/mealImages`
  - Shared by: `MealCatalogService` only
  - Not currently used by orchestrator

### Shared Config

- Gemini API key
  - File: [lib/core/constants/api_key.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/core/constants/api_key.dart:1>)
  - Used by: `AnalystAgent`, `CoachAgent`

- Cached meal database inside `AgentOrchestrator`
  - `_cachedMealDatabase` with 30-minute TTL
  - Data source: Firestore `tunisian_meals`

- In-memory fired flags
  - `AgentScheduler._firedToday`
  - `AgentOrchestrator._firedToday`
  - These are not persisted and are not shared across instances

## 4. Static Connection Map (Node -> Node : reason / method)

### App bootstrap and infrastructure

- `main.dart` -> `Firebase.initializeApp` : initialize Firebase SDK
- `main.dart` -> `PushNotificationService.initialize` : configure FCM listeners
- `main.dart` -> `FoodSeeder.seedAllFoods` : optional debug seeding
- `AppRouter` -> `DashboardScreen` : route navigation
- `AppRouter` -> `OnboardingFlowController` : route navigation
- `AppRouter` -> `AgentOnboardingScreen` : route navigation
- `AppRouter` -> `ChatScreen` : route navigation
- `AppRouter` -> `PlanScreen` : route navigation
- `AppRouter` -> `SwipeScreen` : route navigation

### Upstream profile creation

- `OnboardingProvider` -> `UserRepository` : save built `UserProfile`
- `UserRepository` -> `Firestore` : persist `users/{uid}`
- `UserProvider` -> `UserRepository` : load `users/{uid}`

### Event sources into the agent runtime

- `DashboardScreen` -> `AgentScheduler` : `start(uid)`
- `DashboardScreen` -> `AgentOrchestrator` : `handle(appOpened)`
- `OnboardingFlowController` -> `AgentOrchestrator` : `handle(onboardingComplete)`
- `OnboardingFlowController` -> `AgentScheduler` : `start(uid)`
- `AgentOnboardingScreen` -> `SwipeScreen` : navigation after agent-profile capture
- `AgentOnboardingScreen` -> `AgentOrchestrator` : `handle(onboardingComplete)` after swipe completion
- `AgentOnboardingScreen` -> `AgentScheduler` : `start(uid)`
- `ChatScreen` -> `Firestore chat/{uid}/messages` : persist user message
- `ChatScreen` -> `AgentOrchestrator` : `handle(userMessage)`
- `MealJournalService` -> `Firestore meals/{uid}/logs/.../entries` : persist meal entry
- `MealJournalService` -> `StreakService` : `recordMealLog(uid)`
- `MealJournalService` -> `AgentOrchestrator` : `handle(mealLogged)`
- `AgentScheduler` -> `AgentOrchestrator` : `handle(morningBriefing|middayCheck|eveningSummary|weeklyReview|mealReminder)`

### Core orchestrator supervision

- `AgentOrchestrator` -> `GuardianAgent` : `checkMeal(...)` for logged meal safety
- `AgentOrchestrator` -> `AnalystAgent` : `analyze(uid)` for structured analysis
- `AgentOrchestrator` -> `CoachAgent` : `generateMessage(...)` for user-facing text
- `AgentOrchestrator` -> `FoodScoringService` : `rankMealMaps(...)` for suggestions, swaps, plans
- `AgentOrchestrator` -> `AgentTools` : dashboard pins, meal plans, profile reads, action logs, history reads
- `AgentOrchestrator` -> `MealJournalService` : `confirmPlannedMeal(...)` path logs plan meals as eaten
- `AgentOrchestrator` -> `Firestore meal_plan/{uid}` : direct read/update for plan actions
- `AgentOrchestrator` -> `Firestore chat/{uid}/messages` : save agent reply
- `AgentOrchestrator` -> `Firestore meal_recommendations/{uid}/events` : recommendation telemetry
- `AgentOrchestrator` -> `Firestore tunisian_meals` : load meal DB for plans and deterministic suggestions

### Agent internals

- `AnalystAgent` -> `AgentTools.getUserProfile` : profile fetch
- `AnalystAgent` -> `AgentTools.analyzeDailyLog` : daily nutrition fetch
- `AnalystAgent` -> `AgentTools.getWeeklyHistory` : 7-day nutrition fetch
- `AnalystAgent` -> `Gemini API` : JSON analysis request

- `CoachAgent` -> `Gemini API` : coaching text generation
- `CoachAgent` -> `AgentTools.searchFoodDb` : resolve Gemini `search_food_db` tool call
- `CoachAgent` -> `Gemini API` : function response loop continuation

- `GuardianAgent` -> `AgentTools.getUserProfile` : diabetes check
- `GuardianAgent` -> `Firestore meals/{uid}/logs/...` : write glycemic score and daily aggregate
- `GuardianAgent` -> `CoachAgent.generateMessage` : phrase glycemic warning
- `GuardianAgent` -> `AgentTools.pinToDashboard` : glycemic alert pin
- `GuardianAgent` -> `AgentTools.logAgentAction` : audit alert

### Shared tool layer

- `AgentTools` -> `Firestore users/{uid}` : read/update profile and calorie target
- `AgentTools` -> `Firestore meals/{uid}/logs/...` : read meal diary
- `AgentTools` -> `Firestore dashboard_pins/{uid}` : overwrite active dashboard pin
- `AgentTools` -> `Firestore meal_plan/{uid}` : save plan
- `AgentTools` -> `Firestore agent_actions/{uid}/log` : audit log writes
- `AgentTools` -> `Firestore tunisian_foods` : food search
- `AgentTools` -> `Firestore common_foods` : food search fallback

### Deterministic scoring and learning

- `FoodScoringService` -> `Firestore preferences/{uid}` : load preference maps
- `FoodScoringService` -> `Firestore preferences/{uid}` : write swipe/weekly learning updates
- `SwipePersonalizationService` -> `MealCatalogService` : catalog load/filter
- `SwipePersonalizationService` -> `FoodScoringService` : rank meal maps
- `SwipePersonalizationService` -> `Firestore users/{uid}/swipeState/current` : persist active swipe batch
- `MealCatalogService` -> `assets/production_meals_v2.json` : local catalog load
- `MealCatalogService` -> `Firestore config/mealImages` : merge image URL overrides

### UI consumers of outputs

- `DailyDashboardScreen` -> `Firestore dashboard_pins/{uid}` : stream active pin and optional suggestion card
- `PlanScreen` -> `Firestore meal_plan/{uid}` : read plan
- `PlanScreen` -> `AgentOrchestrator.confirmPlannedMeal` : mark planned meal eaten
- `PlanScreen` -> `AgentOrchestrator.getSwapAlternatives` : retrieve ranked swaps
- `PlanScreen` -> `AgentOrchestrator.confirmSwap` : replace planned meal and log it
- `ChatScreen` -> `Firestore chat/{uid}/messages` : render conversation stream
- `WeeklyInsightsScreen` -> `AgentTools.getWeeklyHistory` : weekly nutrition summary
- `WeeklyInsightsScreen` -> `Firestore meal_plan/{uid}` : plan stats
- `WeeklyInsightsScreen` -> `Firestore agent_actions/{uid}/log` : audit history
- `WeeklyInsightsScreen` -> `Firestore preferences/{uid}` : learned preference scores
- `SwipeScreen` -> `SwipePersonalizationService` : load/build personalized swipe batch

## 5. Key Architectural Findings

- The core agent system is event-driven and supervised by one singleton orchestrator.
- There is no queue, broker, or durable task runner; all dispatch is in-process.
- Dashboard messaging is single-slot, not append-only.
- The agent runtime and the swipe runtime do not share the same meal database today:
  - orchestrator -> Firestore `tunisian_meals`
  - swipe personalization -> asset `production_meals_v2.json`
- `CoachAgent.generateMealSuggestion(...)` exists but is dead code; live suggestions are deterministic orchestrator suggestions.
- `AgentScheduler` is not a singleton, so duplicate periodic timers are possible if `start()` is called from multiple screens.
