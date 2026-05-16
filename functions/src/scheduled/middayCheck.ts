import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {db} from "../admin";
import {listPushEligibleUsers, pruneInvalidToken} from "../users";
import {sendPush} from "../messaging";
import {readDailyLog, tunisDateKey} from "../dailyLog";

/**
 * Midday Check — 12:00 Africa/Tunis.
 *
 * Only pushes for users who have logged under 400 kcal so far today, to
 * catch under-eating patterns early. Users on track stay silent.
 */
export const middayCheck = onSchedule(
  {
    schedule: "0 12 * * *",
    timeZone: "Africa/Tunis",
    region: "europe-west1",
  },
  async () => {
    const users = await listPushEligibleUsers();
    const today = tunisDateKey();
    logger.info("middayCheck: tick", {userCount: users.length, today});

    for (const user of users) {
      const log = await readDailyLog(user.uid, today);
      if (log.totalCalories >= 400) continue;

      const firstName = user.name.split(" ")[0] || "there";
      const message =
        `${firstName}, only ${Math.round(log.totalCalories)} kcal logged ` +
        `so far. Time for a balanced lunch to stay on track for your ` +
        `${user.dailyCalorieGoal} kcal goal.`;
      const pinId = `midday_${today}`;

      await db.collection("dashboard_pins").doc(user.uid).set({
        type: "midday_check",
        message,
        severity: "info",
        foodSuggestion: null,
        pinId,
        createdAt: new Date(),
        dismissed: false,
      });

      const ok = await sendPush(user.fcmToken, {
        title: "FitAI — Midday check",
        body: message,
        type: "midday_check",
        pinId,
      });
      if (!ok) await pruneInvalidToken(user.uid);
    }
  },
);
