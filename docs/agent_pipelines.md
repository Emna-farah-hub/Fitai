# FitAI Agent System - Pipeline Document

This document focuses on data-heavy transformations in the current FitAI codebase.

Format:
- `Stage 1 -> Stage 2 -> Stage 3`
- Each stage names the input, the transformation, and the output

## 1. Meal Logged Reaction Pipeline

### Linear chain

Stage 1 -> `MealEntry` creation in UI / plan / chat
- Input: meal name, quantity/portion, calories, macros, GI, meal type, timestamp
- Process: UI or orchestrator builds a `MealEntry`
- Output: ready-to-persist `MealEntry`

Stage 2 -> `MealJournalService.addMeal(...)`
- Input: `uid`, `MealEntry`
- Process: writes `MealEntry.toMap()` to `meals/{uid}/logs/{date}/entries/{mealId}`
- Output: persisted meal diary entry

Stage 3 -> event emission
- Input: persisted meal + `foodName`
- Process: dispatch `AgentEventType.mealLogged`
- Output: orchestrator event

Stage 4 -> `GuardianAgent.checkMeal(...)`
- Input: `MealEntry`, `uid`
- Process:
  - fetch profile
  - determine diabetes status
  - classify GI
  - annotate entry with `glycemicScore`
  - recompute day average GI
  - optionally build glycemic alert message
- Output:
  - updated meal entry
  - updated day aggregate
  - optional warning pin + audit log

Stage 5 -> `AnalystAgent.analyze(uid)`
- Input:
  - profile
  - today’s meal log
  - weekly history
- Process: Gemini structured JSON analysis
- Output: `AnalysisResult`

Stage 6 -> `CoachAgent.generateMessage(...)`
- Input: `AnalysisResult`, profile, context string
- Process: Gemini user-facing translation, optional `search_food_db` function loop
- Output: coaching text

Stage 7 -> dashboard write
- Input: coaching text + severity + optional suggestion
- Process: overwrite `dashboard_pins/{uid}`
- Output: dashboard agent card visible to user

### Branches / filters
- Non-diabetic user skips most of GuardianAgent.
- `AnalysisResult.status == on_track` suppresses coaching pin on meal log.
- Red GI path creates a warning pin even if the general analysis later says otherwise.

### Failure behavior
- Guardian errors are swallowed.
- Analyst fallback returns `on_track`.
- Coach fallback returns canned text.
- Orchestrator swallows top-level exceptions.

## 2. Chat Reply Pipeline

### Linear chain

Stage 1 -> chat input persistence
- Input: raw user text
- Process: `ChatScreen` writes a `role: user` message to `chat/{uid}/messages`
- Output: user-visible chat row

Stage 2 -> event dispatch
- Input: same user text
- Process: dispatch `AgentEventType.userMessage`
- Output: orchestrator event

Stage 3 -> conversation memory assembly
- Input: last 10 chat rows from Firestore
- Process: reverse into chronological history string
- Output: prompt-ready conversation context

Stage 4 -> profile and analysis fetch
- Input: `uid`
- Process:
  - `AgentTools.getUserProfile`
  - `AnalystAgent.analyze`
- Output:
  - profile map
  - `AnalysisResult`

Stage 5 -> `CoachAgent.generateMessage(...)`
- Input:
  - analysis JSON
  - profile JSON
  - history block
  - current message
- Process:
  - Gemini chat turn
  - optional function-calling loop to `search_food_db`
- Output: agent reply text

Stage 6 -> suggestion intent detection
- Input: current user text
- Process: keyword heuristic for suggestion intent
- Output: boolean + inferred meal type

Stage 7 -> deterministic suggestion pipeline
- Input: `uid`, meal type, today’s meal log, meal database
- Process:
  - filter eaten-today meals
  - rank candidates with `FoodScoringService`
  - convert top result into `SuggestionCard`
- Output: optional `suggestionCard`

Stage 8 -> agent message persistence
- Input: reply text + optional suggestion card
- Process: write `role: agent` message to Firestore
- Output: user-visible agent reply

Stage 9 -> telemetry
- Input: message text, decision, response
- Process: write audit row to `agent_actions/{uid}/log`
- Output: traceable chat action

### Branches / loops
- Function loop repeats until Gemini stops requesting `search_food_db`.
- Suggestion pipeline runs only if intent keywords match.
- Suggestion card can be null even when reply text exists.

### Failure behavior
- User message still exists even if agent fails afterward.
- Coach fallback still allows Stage 8 to complete.

## 3. Analyst Pipeline

### Linear chain

Stage 1 -> profile fetch
- Input: `uid`
- Process: read `users/{uid}`
- Output: profile map

Stage 2 -> daily log aggregation
- Input: today’s meal entry documents
- Process:
  - loop entries
  - sum calories, protein, carbs, fats
  - average GI
  - capture last meal time
- Output: `dailyLog` map

Stage 3 -> weekly history aggregation
- Input: last 7 daily entry subcollections
- Process:
  - loop 7 days
  - loop day entries
  - sum daily macros
  - derive `daysLogged`, `averageDailyCalories`, `mostSkippedMealType`, `consistencyScore`
- Output: `weeklyHistory` map

Stage 4 -> Gemini analysis prompt
- Input: profile + dailyLog + weeklyHistory
- Process: serialize to JSON text and embed in analysis prompt
- Output: prompt string

Stage 5 -> Gemini response cleanup
- Input: raw Gemini text
- Process: strip markdown fences if present
- Output: clean JSON string

Stage 6 -> JSON parse
- Input: clean JSON string
- Process: `jsonDecode` + `AnalysisResult.fromJson`
- Output: typed `AnalysisResult`

### Branches / filters
- Empty API key bypasses Gemini entirely.
- Any exception returns a fallback `AnalysisResult`.

## 4. CoachAgent Function-Calling Pipeline

### Linear chain

Stage 1 -> prompt preparation
- Input: `AnalysisResult`, profile, context string
- Process: build short coaching prompt
- Output: Gemini input text

Stage 2 -> first Gemini turn
- Input: prompt text
- Process: `startChat()` then `sendMessage(...)`
- Output: candidate parts

Stage 3 -> function-call detection
- Input: candidate parts
- Process: inspect for `FunctionCall`
- Output:
  - none -> final text path
  - one/many -> tool loop path

Stage 4 -> local food DB lookup loop
- Input: function call args (`query`)
- Process:
  - call `AgentTools.searchFoodDb(query)`
  - search `tunisian_foods`
  - fallback to `common_foods`
- Output: function response payload

Stage 5 -> Gemini continuation
- Input: one or more `FunctionResponse`s
- Process: send function responses back into Gemini chat
- Output: next Gemini response

Stage 6 -> repeat until no function calls remain
- Input: next response
- Process: loop detection/lookup/continuation
- Output: final agent text

### Branches / loops
- Zero calls -> straight to final text.
- Many calls -> repeat loop until Gemini completes.

### Failure behavior
- Full method fallback to canned text.

## 5. Deterministic Suggestion Pipeline

Used by:
- app-open dashboard suggestions
- morning/midday/reminder suggestions
- chat suggestion cards

### Linear chain

Stage 1 -> meal DB load
- Input: none
- Process: `_loadMealDatabase()` reads Firestore `tunisian_meals`, with a 30-minute in-memory cache
- Output: list of meal maps

Stage 2 -> profile + goal profile fetch
- Input: `uid`
- Process:
  - load profile from `users/{uid}`
  - derive `GoalProfile` from `goals` + `conditions`
- Output: profile + goal profile

Stage 3 -> eaten-today filtering
- Input: daily log + candidate meals for requested meal type
- Process: remove meals whose `name` matches something already eaten today
- Output: recommendation pool

Stage 4 -> ranking
- Input: recommendation pool
- Process: `FoodScoringService.rankMealMaps(...)`
- Output: ranked meals with:
  - goalCompatibilityScore
  - preferenceScore
  - finalScore

Stage 5 -> top-1 selection and packaging
- Input: ranked meals
- Process:
  - pick top result
  - optional second result as alternative
  - compute reason string
  - compute preparation tip
  - compute portion from ingredient quantities
- Output: `SuggestionCard`

Stage 6 -> telemetry write
- Input: chosen ranked meal + source + goal profile
- Process: write `meal_recommendations/{uid}/events`
- Output: recommendation event log

### Branches / filters
- If all typed meals are already eaten, fallback to all typed meals.
- If ranking returns empty, suggestion is null.

### Failure behavior
- Recommendation logging errors are swallowed.

## 6. Weekly Plan Generation Pipeline

### Linear chain

Stage 1 -> meal DB load
- Input: none
- Process: read cached or fresh `tunisian_meals`
- Output: meal database list

Stage 2 -> fallback gate
- Input: meal DB
- Process: if empty, jump to `_saveFallbackPlan(...)`
- Output:
  - normal path if DB exists
  - fallback plan if DB missing

Stage 3 -> profile/goals/preference tags load
- Input: `uid`
- Process:
  - load profile
  - derive goal profile
  - load liked/disliked tag scores from `preferences/{uid}`
  - load current plan version if any
- Output:
  - calorie target
  - goals/conditions
  - liked/disliked tags
  - next version

Stage 4 -> adaptation filtering
- Input:
  - meal list per slot
  - adaptation constraints
- Process:
  - optional flexibility filter
  - optional avoid-swapped-tags filter
- Output: filtered candidate pools

Stage 5 -> slot ranking
- Input:
  - breakfast candidates
  - lunch candidates
  - dinner candidates
  - snack candidates
- Process: rank each slot list independently via `FoodScoringService.rankMealMaps(...)`
- Output: four ranked slot lists

Stage 6 -> 7-day selection loop
- Input:
  - four ranked slot lists
  - used meal IDs
  - previous day protein sources
  - slot calorie targets
- Process:
  - for day 1..7
  - select one meal per slot
  - avoid reused IDs when possible
  - penalize repeated protein sources
  - slightly rotate among shortlist positions by day index
  - attach scoring metadata
- Output: `days` map containing 7 daily meal plans

Stage 7 -> plan persistence
- Input:
  - generation metadata
  - days map
  - target
  - plan version
- Process: save to `meal_plan/{uid}`
- Output: persisted weekly plan

Stage 8 -> user metadata + dashboard output
- Input: new plan info
- Process:
  - update `users/{uid}.lastPlanGeneratedAt` and `planVersion`
  - write `plan_ready` dashboard pin
  - log `plan_generated` audit row
- Output:
  - updated user profile metadata
  - active dashboard pin
  - action log

### Branches / loops
- Full 7-day day loop.
- Candidate shortlist loop inside `_selectPlannedMeal(...)`.
- Fallback plan pipeline if DB empty or generation throws.

### Failure behavior
- Entire generation wrapped in try/catch.
- Any exception falls back to `_saveFallbackPlan(...)`.

## 7. Weekly Learning Pipeline

### Linear chain

Stage 1 -> historical source collection
- Input: `uid`
- Process:
  - load current `meal_plan/{uid}`
  - load `meal_recommendations/{uid}/events`
  - load `preferences/{uid}.swipeHistory`
  - load last 7 days of meal logs
- Output:
  - eaten planned meals
  - skipped planned meals
  - recent recommendation events
  - recent swipe events
  - count of eaten recommendations

Stage 2 -> feedback classification
- Input: raw plan, rec, swipe, log data
- Process:
  - classify confirmed planned meals as positive
  - classify unconfirmed planned meals as skipped/negative
  - classify recent swipes into positive/negative deltas
- Output: structured weekly learning payload

Stage 3 -> preference map mutation
- Input: weekly learning payload + existing `preferences/{uid}`
- Process:
  - update ingredient scores
  - update cuisine scores
  - update tag scores
  - update macro tag scores
  - update meal type scores
  - refresh liked/disliked ingredient lists
- Output: mutated preference document

Stage 4 -> persistence
- Input: mutated preference document
- Process: `set(..., merge: true)` on `preferences/{uid}`
- Output: durable preference state used by future ranking

### Branches / filters
- Recommendation events are filtered to only the last 7 days.
- Swipe history is filtered to only the last 7 days.
- Only entries with `inputMethod` of `agent_suggestion` or `plan_confirmed` count as eaten recommendations.

### Failure behavior
- This path is called from weekly review; upstream orchestrator catches top-level failures.

## 8. Meal Plan Adaptation-Constraint Pipeline

### Linear chain

Stage 1 -> current plan load
- Input: `uid`
- Process: read `meal_plan/{uid}`
- Output: `days` map

Stage 2 -> weekly adherence aggregation
- Input: day slots and meal metadata
- Process:
  - count confirmed per meal type
  - count skipped per meal type
  - sum planned calories
  - sum actual confirmed calories
  - gather tags from swapped meals
- Output: adherence counters + swapped tag list

Stage 3 -> rule evaluation
- Input: counters + calories + swapped tags
- Process:
  - if skipped >= 4 -> quick/easy constraint
  - if adherence < 0.75 -> calorie_low constraint
  - if adherence > 1.15 -> calorie_high constraint
  - if swapped tags exist -> avoid_swapped_tags constraint
  - if skipped >= 3 -> prefer_flexible constraint
- Output: `Map<String, String> adaptationConstraints`

Stage 4 -> downstream reuse
- Input: adaptation constraints
- Process: feed into `generateWeeklyPlan(...)`
- Output: adapted next-week plan behavior

## 9. Swipe Personalization Pipeline

This is outside the orchestrator, but it is a real data-processing subsystem in the codebase.

### Linear chain

Stage 1 -> catalog load
- Input: `assets/production_meals_v2.json`
- Process:
  - parse JSON into `Meal` models
  - optionally merge `config/mealImages.urls` overrides from Firestore
- Output: in-memory meal catalog

Stage 2 -> profile + swipe-state load
- Input: `uid`
- Process:
  - load user profile
  - load swiped IDs from `preferences/{uid}`
  - load current batch from `users/{uid}/swipeState/current` if available
- Output:
  - profile
  - swiped IDs
  - optional active batch

Stage 3 -> safety filtering
- Input: full catalog + profile
- Process: `MealCatalogService.passesSafetyFilter(...)`
- Output: safe meal set

Stage 4 -> cuisine expansion and adjacency
- Input: broad cuisine preferences from profile
- Process:
  - expand broad cuisines to granular catalog cuisines
  - compute adjacent cuisine fallback set
- Output:
  - selected cuisine set
  - adjacent cuisine set

Stage 5 -> ranking
- Input: safe meals
- Process: `FoodScoringService.rankMealMaps(...)`
- Output: ranked safe meals

Stage 6 -> tier partitioning
- Input: ranked meals
- Process: split into:
  - tier 1 selected cuisines
  - tier 2 adjacent cuisines
  - tier 3 all others
- Output: tiered lists

Stage 7 -> batch fill
- Input: tiered lists
- Process: take unique meal IDs in tier order until 15 are collected
- Output: swipe batch

Stage 8 -> batch persistence
- Input: batch IDs
- Process: save `batchMealIds`, `generatedAt`, `seenIds`, `completedAt` in `users/{uid}/swipeState/current`
- Output: durable active swipe batch

### Branches / failure behavior
- Existing active batch short-circuits fresh generation.
- Empty safe set returns an empty batch.

## 10. Food Search Tool Pipeline

Used by:
- `CoachAgent` function-calling loop
- food search UI services elsewhere in the app

### Linear chain

Stage 1 -> query normalization
- Input: raw food name query
- Process: lowercase + trim
- Output: normalized query

Stage 2 -> Tunisian DB scan
- Input: normalized query
- Process: read all docs in `tunisian_foods`, `contains(...)` match on name
- Output:
  - matched food map
  - or continue

Stage 3 -> common DB scan
- Input: normalized query
- Process: read all docs in `common_foods`, `contains(...)` match on name
- Output:
  - matched food map
  - or miss result

Stage 4 -> result packaging
- Input: matched `FoodItem` or no match
- Process: return map with `found: true` and nutrition fields, or `found: false`
- Output: tool response for Gemini or other caller

### Branches / failure behavior
- First match wins.
- On any exception, returns `{found: false, query: query}`.
