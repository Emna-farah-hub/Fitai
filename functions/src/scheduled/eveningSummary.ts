import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {db} from "../admin";
import {listPushEligibleUsers, pruneInvalidToken} from "../users";
import {sendPush} from "../messaging";
import {readDailyLog, tunisDateKey} from "../dailyLog";

/**
 * Evening Summary — 20:00 Africa/Tunis.
 *
 * Recaps the user's nutritional day with a personalised summary message.
 * The body is composed from real values read from `meals/{uid}/logs/{date}`,
 * mirroring how the on-device Analyst Agent builds its summary string.
 */
export const eveningSummary = onSchedule(
  {
    schedule: "0 20 * * *",
    timeZone: "Africa/Tunis",
    region: "europe-west1",
  },
  async () => {
    const users = await listPushEligibleUsers();
    const today = tunisDateKey();
    logger.info("eveningSummary: tick", {userCount: users.length, today});

    for (const user of users) {
      const log = await readDailyLog(user.uid, today);
      const firstName = user.name.split(" ")[0] || "there";
      const target = user.dailyCalorieGoal;
      const consumed = Math.round(log.totalCalories);
      const diff = target - consumed;

      let body: string;
      if (log.mealCount === 0) {
        body =
          `${firstName}, you haven't logged any meals today. ` +
          `A quick log keeps your plan adaptive.`;
      } else if (diff > 200) {
        body =
          `${firstName}, ${consumed}/${target} kcal — you're ${diff} kcal ` +
          `below target. Consider a small evening snack.`;
      } else if (diff < -200) {
        body =
          `${firstName}, ${consumed}/${target} kcal — ${Math.abs(diff)} kcal ` +
          `over today. Aim lighter at dinner tomorrow.`;
      } else {
        body =
          `${firstName}, ${consumed}/${target} kcal logged across ` +
          `${log.mealCount} meals. Solid day!`;
      }

      const pinId = `evening_${today}`;
      await db.collection("dashboard_pins").doc(user.uid).set({
        type: "evening_summary",
        message: body,
        severity: "info",
        foodSuggestion: null,
        pinId,
        createdAt: new Date(),
        dismissed: false,
      });

      const ok = await sendPush(user.fcmToken, {
        title: "FitAI — Evening summary",
        body,
        type: "evening_summary",
        pinId,
      });
      if (!ok) await pruneInvalidToken(user.uid);
    }
  },
);
