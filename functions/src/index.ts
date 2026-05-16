/**
 * FitAI — Cloud Functions entry point.
 *
 * Scheduled triggers fire in Africa/Tunis timezone:
 *   - morningBriefing       08:00 daily
 *   - middayCheck           12:00 daily
 *   - eveningSummary        20:00 daily
 *   - weeklyReview          Sunday 21:00
 *   - mealReminder          every 30 min, 09:00–20:00
 *
 * Firestore trigger:
 *   - onDashboardPinChanged fires on every write to dashboard_pins/{uid},
 *     pushing the orchestrator's in-app pin out as a real FCM notification.
 */
export {morningBriefing} from "./scheduled/morningBriefing";
export {middayCheck} from "./scheduled/middayCheck";
export {eveningSummary} from "./scheduled/eveningSummary";
export {weeklyReview} from "./scheduled/weeklyReview";
export {mealReminder} from "./scheduled/mealReminder";
export {onDashboardPinChanged} from "./triggers/dashboardPinTrigger";
