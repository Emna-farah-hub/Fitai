# FitAI Agent Architecture

This document maps the runtime agent system implemented in the current FitAI codebase.

Scope:
- Agent runtime in [lib/agent](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent>)
- Triggering UI/services that fire agent events
- Shared tooling and scoring layers that agents depend on
- Firestore documents/collections used as shared state and outputs

Out of scope:
- The swipe personalization stack in [lib/services/swipe_personalization_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/swipe_personalization_service.dart>) and [lib/services/meal_catalog_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/meal_catalog_service.dart>) is adjacent to the product AI story, but it is not currently invoked by the `/agent` runtime.

## Runtime Topology

Primary runtime components:
- `AgentScheduler`: time-based event source.
- `AgentOrchestrator`: single event router and supervisor.
- `AnalystAgent`: Gemini-based structured nutrition analysis.
- `CoachAgent`: Gemini-based user-facing coaching and suggestion text.
- `GuardianAgent`: rule-based glycemic safety monitor.

Shared supporting components:
- `AgentTools`: Firestore read/write tool layer used by all agents.
- `FoodScoringService`: deterministic scoring engine used by the orchestrator for plan generation and meal suggestions.
- `MealJournalService`: meal logging entry point that emits `mealLogged` events into the orchestrator.

High-level execution shape:
1. A UI screen, scheduler tick, or service creates an `AgentEvent`.
2. `AgentOrchestrator.handle(...)` routes the event by `AgentEventType`.
3. The orchestrator calls one or more agents and services.
4. Results are persisted to Firestore as:
   - dashboard pins
   - chat messages
   - meal plan documents
   - recommendation logs
   - agent action logs
   - meal log mutations
5. UI screens render those Firestore documents via direct reads or streams.

## Communication and Shared State Map

### In-process communication

- Direct function calls:
  - UI/service -> `AgentOrchestrator.handle(...)`
  - `AgentScheduler` -> `AgentOrchestrator.handle(...)`
  - `AgentOrchestrator` -> `AnalystAgent.analyze(...)`
  - `AgentOrchestrator` -> `CoachAgent.generateMessage(...)`
  - `AgentOrchestrator` -> `GuardianAgent.checkMeal(...)`
  - `AgentOrchestrator` -> `FoodScoringService.rankMealMaps(...)`
  - `GuardianAgent` -> `CoachAgent.generateMessage(...)`
  - `CoachAgent` / `AnalystAgent` -> `AgentTools`

- Tool/function loop inside Gemini:
  - `CoachAgent.generateMessage(...)` can receive `FunctionCall search_food_db`.
  - It resolves the call locally via `AgentTools.searchFoodDb(...)`.
  - It then sends `FunctionResponse` back into the Gemini chat loop.

### No queue / no broker

- There is no persistent job queue, message bus, or background worker.
- Events are dispatched in-process only via `AgentOrchestrator.handle(...)`.
- If the app process dies, in-flight event work is lost.

### Firestore collections used as shared state

- `users/{uid}`
  - user profile, goals, conditions, calorie target, `agentProfile`
- `meals/{uid}/logs/{date}/entries/{mealId}`
  - meal diary entries
- `dashboard_pins/{uid}`
  - single active agent card for dashboard
- `meal_plan/{uid}`
  - generated 7-day plan
- `preferences/{uid}`
  - swipe history, tag scores, ingredient/cuisine/mealType preference maps
- `chat/{uid}/messages`
  - full user/agent chat history
- `agent_actions/{uid}/log`
  - audit trail of orchestrator decisions
- `meal_recommendations/{uid}/events`
  - recommendation telemetry
- `tunisian_foods`, `common_foods`
  - local food lookup used by `search_food_db`
- `tunisian_meals`
  - current meal database used by the orchestrator for plans and deterministic suggestions

Important architecture note:
- The orchestrator still reads Firestore `tunisian_meals` in [orchestrator.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/orchestrator.dart:1417>), while swipe personalization already uses `assets/production_meals_v2.json` via `MealCatalogService`. The agent layer and swipe layer are therefore on different meal catalogs today.

### UI consumers of agent outputs

- Dashboard consumes `dashboard_pins/{uid}` via stream in [daily_dashboard_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/daily_dashboard_screen.dart:405>).
- Chat consumes `chat/{uid}/messages` via stream in [chat_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/chat_screen.dart:218>).
- Plan screen consumes `meal_plan/{uid}` in [plan_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/plan_screen.dart:37>).
- Weekly insights consumes `meal_plan/{uid}`, `agent_actions/{uid}/log`, `preferences/{uid}`, and weekly history via `AgentTools` in [weekly_insights_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/weekly_insights_screen.dart:31>).

## Entry Points Into the Agent System

Current live event sources:
- Dashboard open:
  - [dashboard_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/dashboard/dashboard_screen.dart:43>)
  - Starts scheduler and emits `appOpened`.
- Main onboarding completion:
  - [onboarding_flow_controller.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/onboarding/onboarding_flow_controller.dart:200>)
  - Emits `onboardingComplete` and starts scheduler.
- Legacy/alternate agent onboarding completion:
  - [agent_onboarding_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/agent_onboarding_screen.dart:184>)
  - Emits `onboardingComplete` and starts scheduler after swipe completion.
- Chat send:
  - [chat_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/chat_screen.dart:54>)
  - Emits `userMessage`.
- Meal logging:
  - [meal_journal_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/meal_journal_service.dart:18>)
  - Emits `mealLogged`.
- Scheduler timer tick:
  - [agent_scheduler.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agent_scheduler.dart:39>)
  - Emits `morningBriefing`, `middayCheck`, `eveningSummary`, `weeklyReview`, `mealReminder`.

Non-event orchestrator entry points:
- `generateWeeklyPlan(...)`
- `confirmPlannedMeal(...)`
- `getSwapAlternatives(...)`
- `confirmSwap(...)`

These are invoked directly from the plan UI in [plan_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/plan_screen.dart:917>).

## Agent 1: AgentScheduler

Name / File:
- `AgentScheduler`
- [lib/agent/agent_scheduler.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agent_scheduler.dart:8>)

Trigger / Input:
- Triggered manually by UI calling `start(uid)`.
- Started from:
  - [dashboard_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/dashboard/dashboard_screen.dart:52>)
  - [onboarding_flow_controller.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/onboarding/onboarding_flow_controller.dart:217>)
  - [agent_onboarding_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/agent_onboarding_screen.dart:216>)
- Input is only a user id.

Core Logic:
- Stores `_uid`.
- Runs `_check()` immediately on `start(...)`.
- Runs `_check()` every 30 minutes with `Timer.periodic(...)`.
- Maintains in-memory `_firedToday` keyed by date + event name.
- Emits time-window events:
  - morning: 8-10
  - midday: 12-14
  - evening: 20-22
  - weekly review: Sunday at/after 21:00
  - meal reminders every 3-hour block between 9 and 20

Outputs / Next Step:
- Calls `AgentOrchestrator.handle(...)` with an `AgentEvent`.
- No direct UI output.

External Dependencies:
- `dart:async` `Timer`
- `intl` `DateFormat`
- `AgentOrchestrator`
- `AgentEvent`

Concrete Event Walkthrough:
1. User reaches dashboard after login.
2. `_kickOffAgent()` in [dashboard_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/presentation/screens/dashboard/dashboard_screen.dart:43>) calls `AgentScheduler().start(uid)`.
3. `start(uid)` saves `_uid`, cancels its own previous timer, runs `_check()` immediately, then schedules `Timer.periodic(30 min)`.
4. `_check()` computes current hour, weekday, and `_todayKey`.
5. If the date changed, it clears `_firedToday`.
6. If current time is inside 8-10 and `morning` has not fired, it marks `morning` and dispatches `AgentEventType.morningBriefing`.
7. If current time is inside another window, it can also emit the corresponding event.
8. On the next timer tick, `_check()` repeats and suppresses already-fired events using `_firedToday`.

Failure / Risk Notes:
- `AgentScheduler` is not a singleton. Every `AgentScheduler().start(uid)` call creates a new timer-owning instance. There is no central stop path wired from app lifecycle. That means duplicate schedulers can exist at runtime.

## Agent 2: AgentOrchestrator

Name / File:
- `AgentOrchestrator`
- [lib/agent/orchestrator.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/orchestrator.dart:14>)

Trigger / Input:
- Any `AgentEvent` sent to `handle(...)`.
- Direct method calls from `PlanScreen` for plan interactions:
  - `confirmPlannedMeal(...)`
  - `getSwapAlternatives(...)`
  - `confirmSwap(...)`

Core Logic:
- Singleton supervisor.
- Owns references to:
  - `AgentTools`
  - `FoodScoringService`
  - `AnalystAgent`
  - `CoachAgent`
  - `GuardianAgent`
  - `FirebaseFirestore`
- Routes by `AgentEventType` in `handle(...)`.
- Supervises several workflows:
  - app-open dashboard suggestion
  - meal-logged analysis and glycemic guard
  - scheduled briefings and reminders
  - weekly review and plan regeneration
  - chat reply generation
  - deterministic meal recommendation
  - weekly plan generation
  - plan confirmation / swap flows

Outputs / Next Step:
- Writes to `dashboard_pins/{uid}`
- Writes to `chat/{uid}/messages`
- Writes to `meal_plan/{uid}`
- Writes to `meal_recommendations/{uid}/events`
- Writes to `agent_actions/{uid}/log`
- Updates `users/{uid}` calorie target / plan metadata
- Indirectly writes meal logs through `MealJournalService`

External Dependencies:
- `cloud_firestore`
- `intl`
- `AgentTools`
- `AnalystAgent`
- `CoachAgent`
- `GuardianAgent`
- `FoodScoringService`
- `MealJournalService`

Concrete Event Walkthrough: chat message asking for food
1. User sends a message in [chat_screen.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/screens/chat_screen.dart:54>).
2. `ChatScreen._sendMessage(...)` first writes the user message to `chat/{uid}/messages` so the UI renders instantly.
3. `ChatScreen` dispatches `AgentEventType.userMessage` to `AgentOrchestrator.handle(...)`.
4. `handle(...)` routes to `_handleUserMessage(...)`.
5. `_handleUserMessage(...)` loads the last 10 chat documents from Firestore and serializes them into a text history block.
6. It runs `AnalystAgent.analyze(uid)` to get the latest structured nutrition state.
7. It loads the user profile through `AgentTools.getUserProfile(uid)`.
8. It calls `CoachAgent.generateMessage(...)` with:
   - analysis JSON
   - profile JSON
   - conversation history
   - current message
9. It heuristically checks whether the user wants a suggestion by scanning the lowercase message for phrases like:
   - `what should i eat`
   - `suggest`
   - `hungry`
   - `meal idea`
10. If suggestion intent is true, it chooses a meal slot from current hour and calls `_buildDeterministicSuggestion(...)`.
11. `_buildDeterministicSuggestion(...)` loads the meal database, removes meals already eaten today, ranks candidates through `FoodScoringService.rankMealMaps(...)`, converts the top result into a `SuggestionCard`, and logs telemetry to `meal_recommendations/{uid}/events`.
12. `_handleUserMessage(...)` writes one new Firestore message with role `agent`, the generated text, and optional `suggestionCard`.
13. It logs the action to `agent_actions/{uid}/log`.

Branching / Failure Paths:
- If Gemini fails in `CoachAgent`, a fallback coaching message is used.
- If no ranked suggestion is available, `suggestionCard` stays null.
- All top-level orchestrator exceptions are swallowed in `handle(...)`.

Important Orchestration Notes:
- Dashboard pins are last-write-wins because `AgentTools.pinToDashboard(...)` writes a single document at `dashboard_pins/{uid}`.
- The orchestrator keeps its own in-memory `_firedToday` for briefings, separate from the scheduler's in-memory `_firedToday`.
- The orchestrator plan/recommendation engine still uses Firestore `tunisian_meals`, not the newer production asset catalog used by swipe.

## Agent 3: AnalystAgent

Name / File:
- `AnalystAgent`
- [lib/agent/agents/analyst_agent.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agents/analyst_agent.dart:65>)

Trigger / Input:
- Called only by in-process consumers.
- Main callers:
  - `AgentOrchestrator._handleMealLogged(...)`
  - `AgentOrchestrator._handleMorningBriefing(...)`
  - `AgentOrchestrator._handleEveningSummary(...)`
  - `AgentOrchestrator._handleWeeklyReview(...)`
  - `AgentOrchestrator._handleUserMessage(...)`

Core Logic:
- Gemini-powered analysis agent with model `gemini-2.0-flash`.
- System instruction forces JSON-only structured output.
- Reads:
  - user profile
  - today's meal log
  - weekly history
- Prompts Gemini to return:
  - `status`
  - `summary`
  - `gaps`
  - `risks`
  - `priority`
  - `suggestedAction`
  - `behaviorPattern`
  - `planAdjustmentNeeded`
- Parses JSON into `AnalysisResult`.
- Returns `AnalysisResult.fallback()` if:
  - API key is empty
  - Gemini call fails
  - JSON parse fails

Outputs / Next Step:
- Returns `AnalysisResult` to caller.
- Does not write to Firestore directly.
- Does not speak to the user directly.

External Dependencies:
- `google_generative_ai`
- local API key in [api_key.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/core/constants/api_key.dart:1>)
- `AgentTools`
- `dart:convert`

Concrete Event Walkthrough: meal logged analysis
1. `MealJournalService.addMeal(...)` persists a new `MealEntry`.
2. The same service emits `AgentEventType.mealLogged`.
3. `AgentOrchestrator._handleMealLogged(...)` receives the event.
4. After optional glycemic checking, the orchestrator calls `AnalystAgent.analyze(uid)`.
5. `AnalystAgent` fetches:
   - profile from `users/{uid}`
   - today's meals from `meals/{uid}/logs/{today}/entries`
   - seven-day history via repeated daily log reads
6. It sends one Gemini prompt containing all three serialized data blocks.
7. Gemini returns structured JSON.
8. `AnalystAgent` strips optional markdown fences, parses JSON, and returns `AnalysisResult`.
9. The orchestrator uses that result to decide whether to pin a coaching message and what to log.

Failure Paths:
- If Gemini is unavailable, `AnalysisResult.fallback()` returns `status: on_track`.
- That fallback can suppress downstream warning behavior because the orchestrator treats `on_track` as no message needed.

## Agent 4: CoachAgent

Name / File:
- `CoachAgent`
- [lib/agent/agents/coach_agent.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agents/coach_agent.dart:64>)

Trigger / Input:
- Called by the orchestrator for:
  - morning briefing
  - meal-logged coaching tip
  - evening summary
  - weekly review summary
  - user chat reply
- Called by `GuardianAgent` for glycemic alerts.

Core Logic:
- Gemini-powered user-facing messaging agent using `gemini-2.0-flash`.
- Configured with one function-calling tool:
  - `search_food_db(query)`
- Live production path is `generateMessage(...)`.
- Unused path: `generateMealSuggestion(...)` exists but is not called anywhere in the codebase; deterministic suggestions currently live inside the orchestrator instead.
- `generateMessage(...)`:
  - builds prompt from `AnalysisResult`, profile, and context
  - starts Gemini chat
  - loops while Gemini returns `FunctionCall`s
  - resolves `search_food_db` with `AgentTools.searchFoodDb(...)`
  - sends `FunctionResponse` back into Gemini
  - returns final text or fallback message

Outputs / Next Step:
- Returns a coaching string to caller.
- The caller decides whether to pin it to the dashboard, persist it as chat, or ignore it.

External Dependencies:
- `google_generative_ai`
- local Gemini API key
- `AgentTools`
- `AnalysisResult`

Concrete Event Walkthrough: chat request with food suggestion
1. User sends "What should I eat for lunch?" in `ChatScreen`.
2. `AgentOrchestrator._handleUserMessage(...)` gathers conversation history, profile, and analysis.
3. It calls `CoachAgent.generateMessage(...)`.
4. `CoachAgent` sends the prompt into Gemini.
5. Gemini may respond with one or more `FunctionCall search_food_db`.
6. `CoachAgent` loops those calls and forwards each `query` into `AgentTools.searchFoodDb(...)`.
7. `AgentTools.searchFoodDb(...)` scans Firestore `tunisian_foods` first, then `common_foods`, and returns nutrition payload or `{found:false}`.
8. `CoachAgent` sends the function results back to Gemini via `Content.functionResponses(...)`.
9. When Gemini stops requesting functions, `CoachAgent` returns plain text.
10. The orchestrator separately decides whether to attach a deterministic `SuggestionCard` based on keyword intent.

Branching / Failure Paths:
- If the API key is empty or Gemini fails, `CoachAgent` returns a fallback canned message.
- If Gemini asks for multiple function calls, the loop resolves all calls in one turn.

## Agent 5: GuardianAgent

Name / File:
- `GuardianAgent`
- [lib/agent/agents/guardian_agent.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/agents/guardian_agent.dart:8>)

Trigger / Input:
- Called only by `AgentOrchestrator._handleMealLogged(...)`.
- Input is a `MealEntry` plus `uid`.

Core Logic:
- Pure rule-based safety agent.
- Reads the user profile and exits early unless the user is diabetic.
- Classifies meal GI:
  - `green` <= 55
  - `orange` <= 69
  - `red` >= 70
- Updates the meal entry document with `glycemicScore`.
- Recomputes and stores daily `averageGI` and `mealCount`.
- If the meal is `red`, it synthesizes a minimal `AnalysisResult` and asks `CoachAgent` to phrase a warning message.

Outputs / Next Step:
- Updates meal log Firestore documents.
- Optionally writes a warning pin to `dashboard_pins/{uid}`.
- Logs a glycemic alert action.

External Dependencies:
- `cloud_firestore`
- `AgentTools`
- `CoachAgent`
- `MealEntry`

Concrete Event Walkthrough: diabetic user logs a high-GI meal
1. A meal is added with `MealJournalService.addMeal(...)`.
2. `MealJournalService` dispatches `mealLogged`.
3. `AgentOrchestrator._handleMealLogged(...)` sees `payload['meal']` and calls `GuardianAgent.checkMeal(...)`.
4. `GuardianAgent` loads the user profile from Firestore.
5. It checks goals and conditions for the substring `diabetes`.
6. If the user is not diabetic, it returns immediately.
7. If diabetic, it maps `meal.glycemicIndex` to `green`, `orange`, or `red`.
8. It updates the specific meal entry document with `glycemicScore`.
9. It reads all entries for that day, computes mean GI, and stores `averageGI` and `mealCount` on the day document.
10. If the meal is `red`, it builds an `AnalysisResult(status: glycemic_risk, ...)`.
11. It calls `CoachAgent.generateMessage(...)` with context like `User just ate ... with GI ...`.
12. It writes a `glycemic_alert` dashboard pin and an `agent_actions` log row.

Failure Paths:
- All exceptions are swallowed by design.
- If coach generation fails, `CoachAgent` fallback text is used if the call itself returns.

## Shared Tool Layer: AgentTools

Name / File:
- `AgentTools`
- [lib/agent/tools/agent_tools.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/agent/tools/agent_tools.dart:6>)

Trigger / Input:
- Called by all agents and the weekly insights screen.

Core Logic:
- Firestore-only tool wrapper.
- Read tools:
  - `classifyFoodResult(...)`
  - `analyzeDailyLog(...)`
  - `getUserProfile(...)`
  - `searchFoodDb(...)`
  - `getWeeklyHistory(...)`
- Write tools:
  - `pinToDashboard(...)`
  - `updateCalorieTarget(...)`
  - `saveMealPlan(...)`
  - `logAgentAction(...)`

Outputs / Next Step:
- Returns plain maps to callers.
- Persists dashboard pins, meal plans, calorie target changes, and audit logs.

External Dependencies:
- `cloud_firestore`
- `intl`
- `FoodItem`
- `MealEntry`

Important Shared-State Note:
- `pinToDashboard(...)` writes to `dashboard_pins/{uid}` as a single document, so a new pin overwrites the previous one instead of appending to a queue.

## Shared Scoring Engine: FoodScoringService

Name / File:
- `FoodScoringService`
- [lib/services/food_scoring_service.dart](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/food_scoring_service.dart:50>)

Trigger / Input:
- Called by:
  - `AgentOrchestrator.generateWeeklyPlan(...)`
  - `AgentOrchestrator._buildDeterministicSuggestion(...)`
  - `AgentOrchestrator.getSwapAlternatives(...)`
  - `SwipePersonalizationService` (outside the agent runtime)

Core Logic:
- Derives one `GoalProfile` from `goals` + `conditions`.
- Loads preference maps from `preferences/{uid}`.
- Rejects meals that are not goal-safe.
- Scores survivors on two axes:
  - goal compatibility
  - learned user preference
- Combines them into `finalScore = 0.6 * goal + 0.4 * preference`.
- Learns from:
  - swipe likes/dislikes
  - confirmed planned meals
  - skipped planned meals
  - recommendation telemetry

Outputs / Next Step:
- Returns ranked meal lists.
- Updates `preferences/{uid}` during swipe/weekly learning.

External Dependencies:
- `cloud_firestore`
- `Meal`
- `FoodItem`

Concrete Event Walkthrough: weekly learning
1. `AgentOrchestrator._handleWeeklyReview(...)` calls `_performWeeklyLearning(uid)`.
2. `_performWeeklyLearning(...)` reads:
   - `meal_plan/{uid}`
   - `meal_recommendations/{uid}/events`
   - `preferences/{uid}.swipeHistory`
   - last 7 days of `meals/{uid}/logs/.../entries`
3. It computes:
   - eaten planned meals
   - skipped planned meals
   - recent recommendation count
   - recent swipe events
   - count of eaten recommendations
4. It calls `FoodScoringService.applyWeeklyLearning(...)`.
5. `applyWeeklyLearning(...)` mutates preference maps by applying positive or negative deltas to ingredients, cuisine, tags, macro tags, and meal type preferences.
6. It writes the updated preference document back to `preferences/{uid}`.
7. The next plan generation and deterministic suggestion call will automatically rank meals against the new preference state.

## Real Data Flow by Major Scenario

### Scenario A: User logs a meal manually or from a suggestion
1. UI builds `MealEntry`.
2. [MealJournalService.addMeal(...)](</C:/Users/amoun/AndroidStudioProjects/fitai/lib/services/meal_journal_service.dart:18>) writes it to Firestore.
3. `MealJournalService` updates streak state.
4. `MealJournalService` emits `mealLogged`.
5. `AgentOrchestrator._handleMealLogged(...)` calls:
   - `GuardianAgent.checkMeal(...)`
   - `AnalystAgent.analyze(...)`
   - `CoachAgent.generateMessage(...)` if status is not `on_track`
6. Orchestrator writes dashboard pin and action log.
7. Dashboard stream updates automatically if a pin was written.

### Scenario B: User finishes onboarding
1. Onboarding UI calls `AgentOrchestrator.handle(onboardingComplete)`.
2. The orchestrator waits 2 seconds in `_handleOnboardingComplete(...)`.
3. It calls `generateWeeklyPlan(uid, reason: 'initial')`.
4. `generateWeeklyPlan(...)` loads meal database from Firestore `tunisian_meals`.
5. It loads profile and preference tags, then ranks meal candidates by slot with `FoodScoringService.rankMealMaps(...)`.
6. It selects 4 meals per day for 7 days with variety and calorie heuristics.
7. It writes `meal_plan/{uid}` and updates user plan metadata.
8. It writes a `plan_ready` dashboard pin and an action log row.
9. `PlanScreen` can now render the plan.

### Scenario C: User taps "I ate this" on a planned meal
1. `PlanScreen._markEaten(...)` calls `AgentOrchestrator.confirmPlannedMeal(...)`.
2. `confirmPlannedMeal(...)` reads the selected meal from `meal_plan/{uid}`.
3. It converts the planned meal into a `MealEntry` with `inputMethod: 'plan_confirmed'`.
4. It calls `MealJournalService.addMeal(...)`.
5. `MealJournalService` writes the meal and emits `mealLogged`.
6. The full meal-logged pipeline runs again:
   - Guardian check
   - Analyst analysis
   - optional coaching pin
7. `confirmPlannedMeal(...)` then marks that plan slot `confirmed: true` in `meal_plan/{uid}`.
8. Weekly learning will later treat this as an eaten recommendation.

## Observed Architecture Constraints / Risks

1. Scheduler duplication risk
- `AgentScheduler` is instantiated ad hoc and is not a singleton.
- Multiple starts can create multiple active timers and duplicate scheduled events.

2. Duplicate suppression is only in memory
- Both scheduler and orchestrator use in-memory `_firedToday`.
- That state is lost on restart and is not shared across instances.

3. Dashboard pins are not a queue
- `dashboard_pins/{uid}` is a single document.
- New pin writes overwrite prior pins.

4. Agent meal database is not aligned with swipe catalog
- Orchestrator uses Firestore `tunisian_meals`.
- Swipe uses `production_meals_v2.json` through `MealCatalogService`.
- This means recommendations/plans and swipe personalization are currently driven by different datasets.

5. `CoachAgent.generateMealSuggestion(...)` is dead code
- The method exists, but no caller invokes it.
- Meal suggestions in live flows are deterministic orchestrator suggestions, not Gemini-generated suggestion cards.

6. Error handling is intentionally soft
- Top-level agent paths usually swallow exceptions.
- This keeps UX resilient, but it also hides operational failures unless developers inspect Firestore outputs or logs.

## Diagram-Building Summary

If you are drawing workflow diagrams, the most important nodes and edges are:

- Event sources:
  - Dashboard open
  - Onboarding complete
  - Chat send
  - Meal log write
  - Scheduler tick

- Central router:
  - `AgentOrchestrator.handle(event)`

- Specialist agents:
  - `GuardianAgent`
  - `AnalystAgent`
  - `CoachAgent`

- Deterministic engines:
  - `FoodScoringService`
  - plan selection helpers in `AgentOrchestrator`

- Shared data state:
  - `users`
  - `meals/logs/entries`
  - `preferences`
  - `dashboard_pins`
  - `meal_plan`
  - `chat/messages`
  - `agent_actions/log`
  - `meal_recommendations/events`

- UI consumers:
  - Dashboard card
  - Chat stream
  - Plan screen
  - Weekly insights
