# FitAI Agent System - Workflow Document

This document gives step-by-step, concrete execution flows for the real agent paths implemented in the code today.

## 1. AgentScheduler Workflow

Concrete event:
- Morning briefing dispatch from a scheduler tick

Trigger:
- A screen starts the scheduler with `AgentScheduler().start(uid)`, usually from:
  - [DashboardScreen](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/dashboard/dashboard_screen.dart:43>)
  - [OnboardingFlowController](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/onboarding/onboarding_flow_controller.dart:200>)
  - [AgentOnboardingScreen](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/agent_onboarding_screen.dart:184>)

Step-by-step flow:
1. UI calls `AgentScheduler.start(uid)`.
2. `start(uid)` stores `_uid`, cancels the previous timer on that same instance, runs `_check()` immediately, and creates `Timer.periodic(Duration(minutes: 30))`.
3. `_check()` exits immediately if `_uid` is null.
4. `_check()` compares today’s date key with `_lastDateKey`.
5. If the day changed, it clears `_firedToday` and updates `_lastDateKey`.
6. `_check()` reads current hour and weekday.
7. It evaluates time-window conditions in order:
   - morning briefing
   - midday check
   - evening summary
   - weekly review
   - meal reminder block
8. If current hour is between 8 and 10 and `morning` has not fired today, it marks `morning` as fired.
9. It dispatches `AgentEvent.now(type: AgentEventType.morningBriefing, uid: uid)` to `AgentOrchestrator.handle(...)`.
10. The timer remains active and repeats every 30 minutes.

Branching logic:
- If the current time is not inside a window, nothing fires.
- If a window has already fired for the day/block, that event is skipped.
- Weekly review only fires on Sunday after 21:00.

Failure / fallback behavior:
- No try/catch here; dispatch errors are handled downstream by the orchestrator.
- Scheduler state is in-memory only. App restarts reset its firing memory.

Final output / side effect:
- Emits one `AgentEvent` into the orchestrator.

## 2. AgentOrchestrator Workflow

Concrete event:
- User sends a chat message asking for a meal suggestion

Trigger:
- [ChatScreen._sendMessage(...)](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/chat_screen.dart:54>) dispatches `AgentEventType.userMessage`

Step-by-step flow:
1. `ChatScreen` writes the user’s message to `chat/{uid}/messages` before the agent call.
2. `ChatScreen` calls `AgentOrchestrator.handle(AgentEventType.userMessage)`.
3. `AgentOrchestrator.handle(...)` routes by `switch (event.type)` into `_handleUserMessage(event)`.
4. `_handleUserMessage(...)` reads the last 10 chat messages from Firestore, ordered descending, then reverses them into chronological history text.
5. It calls `AnalystAgent.analyze(uid)` to get the latest structured nutrition state.
6. It calls `AgentTools.getUserProfile(uid)` to fetch the profile.
7. It calls `CoachAgent.generateMessage(...)` with:
   - current analysis
   - profile
   - conversation history
   - current user message
8. It lowercases the current user message and checks for suggestion-intent keywords:
   - `what should i eat`
   - `suggest`
   - `hungry`
   - `meal idea`
9. If no suggestion intent is detected:
   - it skips deterministic suggestion building.
10. If suggestion intent is detected:
   - it chooses `Breakfast`, `Lunch`, `Dinner`, or `Snack` from the current hour.
   - it calls `_buildDeterministicSuggestion(uid, mealType, source: 'user_message')`.
11. `_buildDeterministicSuggestion(...)`:
   - loads the meal DB from Firestore `tunisian_meals`
   - loads profile/goals/conditions
   - loads today’s meals
   - removes meals already eaten today
   - ranks remaining meals using `FoodScoringService.rankMealMaps(...)`
   - takes the top result
   - converts it to `SuggestionCard`
   - logs telemetry to `meal_recommendations/{uid}/events`
12. `_handleUserMessage(...)` writes a new `role: agent` chat message to Firestore with:
   - generated text
   - optional `suggestionCard`
13. `_handleUserMessage(...)` writes an audit row to `agent_actions/{uid}/log`.

Branching logic:
- If suggestion intent is false, there is no suggestion card.
- If all candidate meals were already eaten today, it falls back to all meals of that meal type.
- If the ranked list is empty, no suggestion card is attached.

Failure / fallback behavior:
- `handle(...)` catches all top-level exceptions and swallows them.
- If `CoachAgent` fails, its fallback message is still written if returned.
- If suggestion generation fails, the agent reply still gets stored without a card.

Final output / side effect:
- Firestore write to `chat/{uid}/messages`
- Firestore write to `agent_actions/{uid}/log`
- Optional Firestore write to `meal_recommendations/{uid}/events`

## 3. AnalystAgent Workflow

Concrete event:
- Meal-logged nutritional analysis

Trigger:
- `AgentOrchestrator._handleMealLogged(...)` calls `AnalystAgent.analyze(uid)` after a meal log event

Step-by-step flow:
1. A meal is logged through `MealJournalService.addMeal(...)`.
2. `MealJournalService` emits `AgentEventType.mealLogged`.
3. `AgentOrchestrator._handleMealLogged(...)` begins processing.
4. If `payload['meal']` exists, the orchestrator first calls `GuardianAgent.checkMeal(...)`.
5. The orchestrator then calls `AnalystAgent.analyze(uid)`.
6. `AnalystAgent.analyze(uid)` checks whether the Gemini API key exists.
7. If the key is empty, it returns `AnalysisResult.fallback()` immediately.
8. Otherwise it fetches:
   - `profile = AgentTools.getUserProfile(uid)`
   - `dailyLog = AgentTools.analyzeDailyLog(uid)`
   - `weeklyHistory = AgentTools.getWeeklyHistory(uid)`
9. It constructs a single prompt containing all three data blocks as JSON strings.
10. It sends the prompt to Gemini using model `gemini-2.0-flash`.
11. It receives `response.text`.
12. It strips optional markdown code fences with `_cleanJson(...)`.
13. It parses JSON into `Map<String, dynamic>`.
14. It converts the map to `AnalysisResult.fromJson(...)`.
15. It returns the `AnalysisResult` to the orchestrator.
16. The orchestrator checks `analysis.status`.
17. If the status is not `on_track`, it asks `CoachAgent` to translate the analysis into a user-facing message.
18. It may pin that message to the dashboard and always logs an agent action.

Branching logic:
- Fallback path if API key missing.
- Fallback path if any fetch, Gemini call, JSON cleaning, or JSON parse fails.
- Downstream branch:
  - `on_track` -> no coaching pin
  - anything else -> coaching pin

Failure / fallback behavior:
- Returns `AnalysisResult.fallback()` on any error.
- Fallback result is intentionally conservative and non-blocking.

Final output / side effect:
- Returns `AnalysisResult` only.
- No direct Firestore writes from the analyst itself.

## 4. CoachAgent Workflow

Concrete event:
- Chat response with Gemini function-calling loop

Trigger:
- `AgentOrchestrator._handleUserMessage(...)` calls `CoachAgent.generateMessage(...)`

Step-by-step flow:
1. `CoachAgent.generateMessage(...)` checks whether the Gemini API key exists.
2. If missing, it returns `_fallbackMessage(analysis)` immediately.
3. Otherwise it builds a prompt from:
   - `AnalysisResult`
   - profile map
   - free-form context string
4. It starts a Gemini chat session with `_gemini.startChat()`.
5. It sends the prompt as the first chat turn.
6. It inspects the returned candidate parts.
7. While the current Gemini response contains any `FunctionCall` parts:
   1. Collect all function calls from the candidate.
   2. For each call:
      - if `call.name == 'search_food_db'`
      - read `query`
      - call `AgentTools.searchFoodDb(query)`
      - wrap the result in a `FunctionResponse`
   3. Send all function responses back to Gemini with `Content.functionResponses(...)`.
   4. Receive the next Gemini response.
8. Once Gemini stops requesting function calls, return `response.text`.
9. If `response.text` is null, return `_fallbackMessage(analysis)`.

Branching logic:
- Zero tool calls -> single-turn completion
- One or many tool calls -> loop until no `FunctionCall` remains

Failure / fallback behavior:
- Entire method is wrapped in try/catch.
- Any exception returns `_fallbackMessage(analysis)`.

Final output / side effect:
- Returns a short coaching message string
- No direct Firestore writes

## 5. GuardianAgent Workflow

Concrete event:
- Diabetic user logs a high-GI meal

Trigger:
- `AgentOrchestrator._handleMealLogged(...)` calls `GuardianAgent.checkMeal(meal, uid)`

Step-by-step flow:
1. `checkMeal(...)` fetches the user profile through `AgentTools.getUserProfile(uid)`.
2. If `profile['found']` is false, it returns.
3. It extracts `goals` and `conditions`.
4. It checks whether any goal or condition string contains `diabetes`.
5. If the user is not diabetic, it returns immediately.
6. It reads `meal.glycemicIndex`.
7. It classifies glycemic level:
   - `green` if `gi <= 55`
   - `orange` if `gi <= 69`
   - `red` otherwise
8. It updates the specific meal entry document with `glycemicScore`.
9. It calls `_updateDailyGlycemic(uid, meal.date)`.
10. `_updateDailyGlycemic(...)`:
    - fetches all meal entries for that date
    - loops them
    - sums valid GI values
    - computes average
    - writes `averageGI` and `mealCount` to the daily log document
11. Back in `checkMeal(...)`, it branches on glycemic level.
12. If the level is not `red`, the workflow stops here.
13. If the level is `red`:
    - it constructs a synthetic `AnalysisResult(status: glycemic_risk, ...)`
    - it calls `CoachAgent.generateMessage(...)` with a glycemic-risk context string
    - it writes a `glycemic_alert` dashboard pin
    - it writes an `agent_actions` audit row

Branching logic:
- Non-diabetic -> immediate exit
- Diabetic + green/orange -> annotate meal and update aggregate only
- Diabetic + red -> annotate meal, update aggregate, coach message, dashboard pin, audit log

Failure / fallback behavior:
- Entire method is wrapped in try/catch and swallows all errors.
- `_updateDailyGlycemic(...)` also swallows its own errors.

Final output / side effect:
- Updates meal entry
- Updates day aggregate
- Optionally pins a glycemic alert to dashboard
- Optionally logs alert action

## 6. Supporting Workflow: MealJournalService

Concrete event:
- Add a meal from manual logging, plan confirmation, or chat suggestion

Trigger:
- Called from multiple UI paths and from orchestrator plan confirmation

Step-by-step flow:
1. `MealJournalService.addMeal(uid, meal)` writes the `MealEntry` to Firestore.
2. It tries to trigger haptic feedback.
3. It records meal-log streak via `StreakService().recordMealLog(uid)`.
4. It dispatches `AgentEventType.mealLogged` into the orchestrator with payload:
   - `meal`
   - `foodName`
5. It invokes the optional `onMealLogged` callback if one is registered.

Branching logic:
- Haptics and callback are best-effort only.

Failure / fallback behavior:
- Haptic and callback failures are swallowed.
- Orchestrator dispatch is wrapped in try/catch.

Final output / side effect:
- Firestore meal log write
- streak update
- downstream agent reaction

## 7. Supporting Workflow: Weekly Plan Interaction

Concrete event:
- User taps “I ate this” on a planned meal

Trigger:
- [PlanScreen._markEaten(...)](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/plan_screen.dart:917>) calls `AgentOrchestrator.confirmPlannedMeal(...)`

Step-by-step flow:
1. `PlanScreen` reads the selected planned meal name for snackbar UX.
2. It calls `AgentOrchestrator.confirmPlannedMeal(uid, dayNumber, mealType)`.
3. The orchestrator fetches `meal_plan/{uid}`.
4. It reads the selected day and slot (`breakfast`, `lunch`, `dinner`, or `snack`).
5. It computes a total quantity from ingredient quantities; if zero, it falls back to `100`.
6. It converts the planned meal map into a `MealEntry` with:
   - current timestamp
   - `inputMethod: 'plan_confirmed'`
7. It calls `MealJournalService.addMeal(uid, entry)`.
8. That service writes the meal log and emits `mealLogged`.
9. The full meal-logged pipeline runs:
   - Guardian
   - Analyst
   - optional Coach/dashboard pin
10. After the meal is logged, `confirmPlannedMeal(...)` marks the planned slot `confirmed = true` in `meal_plan/{uid}`.
11. `PlanScreen` reloads its plan state and shows a snackbar.

Failure / fallback behavior:
- `confirmPlannedMeal(...)` catches exceptions and only logs them with `debugPrint`.
- `PlanScreen` shows a generic failure snackbar if the round-trip fails.

Final output / side effect:
- Meal log entry created
- Optional downstream coaching/glycemic outputs
- Plan slot marked confirmed

## 8. Supporting Workflow: Swipe Personalization

Concrete event:
- Swipe screen opens and needs a fresh batch

Trigger:
- [SwipeScreen._loadMeals(...)](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/swipe_screen.dart:88>)

Step-by-step flow:
1. `SwipeScreen` calls `SwipePersonalizationService.loadExistingBatch(uid)`.
2. If a non-completed current batch exists in `users/{uid}/swipeState/current`, it loads those meal IDs from the catalog and returns them.
3. If there is no active batch, `SwipeScreen` loads profile and swiped IDs.
4. It calls `SwipePersonalizationService.buildSwipeBatch(...)`.
5. The personalization service initializes `MealCatalogService`.
6. It expands broad cuisine labels to granular catalog cuisines.
7. It computes adjacent cuisines for fallback.
8. It excludes already swiped IDs.
9. It filters the full catalog with `MealCatalogService.passesSafetyFilter(...)`.
10. It ranks safe meals with `FoodScoringService.rankMealMaps(...)`.
11. It partitions ranked meals into:
    - selected cuisines
    - adjacent cuisines
    - all other cuisines
12. It fills a batch up to 15 cards in that tier order.
13. It saves the batch IDs to `users/{uid}/swipeState/current`.
14. `SwipeScreen` renders the batch.
15. Each swipe records learned preference feedback and `seenIds`.

Important note:
- This is a real AI-adjacent workflow in the codebase, but it is separate from the `/agent` runtime.
