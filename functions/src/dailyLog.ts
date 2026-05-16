import {db} from "./admin";

export interface DailyLogSummary {
  date: string; // yyyy-MM-dd
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFats: number;
  mealCount: number;
  averageGlycemicIndex: number;
  lastMealTimeIso: string | null;
}

/**
 * Reads the daily meal log for a user.
 *
 * Mirrors the on-device implementation in `lib/agent/tools/agent_tools.dart`
 * so scheduled functions can produce personalised messages using the same
 * data the Orchestrator does on-device.
 */
export async function readDailyLog(
  uid: string,
  dateKey: string,
): Promise<DailyLogSummary> {
  const snap = await db
    .collection("meals")
    .doc(uid)
    .collection("logs")
    .doc(dateKey)
    .collection("entries")
    .orderBy("timestamp")
    .get();

  let totalCalories = 0;
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFats = 0;
  let totalGi = 0;
  let lastMealTimeIso: string | null = null;

  for (const doc of snap.docs) {
    const d = doc.data();
    totalCalories += (d.calories as number) ?? 0;
    totalProtein += (d.protein as number) ?? 0;
    totalCarbs += (d.carbs as number) ?? 0;
    totalFats += (d.fats as number) ?? 0;
    totalGi += (d.glycemicIndex as number) ?? 0;
    const ts = d.timestamp;
    if (ts && typeof ts.toDate === "function") {
      lastMealTimeIso = (ts.toDate() as Date).toISOString();
    }
  }

  const mealCount = snap.size;
  return {
    date: dateKey,
    totalCalories,
    totalProtein,
    totalCarbs,
    totalFats,
    mealCount,
    averageGlycemicIndex: mealCount > 0 ? totalGi / mealCount : 0,
    lastMealTimeIso,
  };
}

/** Tunis timezone helper: today's date key in yyyy-MM-dd. */
export function tunisDateKey(now: Date = new Date()): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Tunis",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(now); // en-CA emits yyyy-MM-dd
}
