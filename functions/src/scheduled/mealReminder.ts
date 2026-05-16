import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {db} from "../admin";
import {listPushEligibleUsers, pruneInvalidToken} from "../users";
import {sendPush} from "../messaging";
import {readDailyLog, tunisDateKey} from "../dailyLog";

const HOURS_3 = 3 * 60 * 60 * 1000;

/**
 * Meal Reminder — every 30 minutes between 09:00 and 20:00 Africa/Tunis.
 *
 * Fires only for users whose last meal timestamp is more than 3 hours ago.
 * Each user receives at most one reminder per "3-hour block" of the day,
 * so they don't get spammed if they remain inactive.
 */
export const mealReminder = onSchedule(
  {
    schedule: "*/30 9-20 * * *",
    timeZone: "Africa/Tunis",
    region: "europe-west1",
  },
  async () => {
    const users = await listPushEligibleUsers();
    const today = tunisDateKey();
    const now = new Date();
    const hour = parseInt(
      new Intl.DateTimeFormat("en-GB", {
        timeZone: "Africa/Tunis",
        hour: "2-digit",
        hour12: false,
      }).format(now),
      10,
    );
    const block = Math.floor(hour / 3); // 0..7
    logger.info("mealReminder: tick", {userCount: users.length, hour, block});

    for (const user of users) {
      const log = await readDailyLog(user.uid, today);
      let stale = true;
      if (log.lastMealTimeIso) {
        const last = new Date(log.lastMealTimeIso).getTime();
        stale = now.getTime() - last >= HOURS_3;
      }
      if (!stale) continue;

      const firstName = user.name.split(" ")[0] || "there";
      const suggestedType =
        hour < 10 ? "Breakfast" :
          hour < 14 ? "Lunch" :
            hour < 20 ? "Dinner" : "Snack";
      const body = log.lastMealTimeIso ?
        `${firstName}, it's been over 3 hours. Time for ${suggestedType}?` :
        `${firstName}, you haven't logged a meal yet. Open FitAI to log ${suggestedType}.`;

      const pinId = `reminder_${today}_${block}`;

      // Idempotency: skip if a reminder for this block was already pinned today.
      const pinRef = db.collection("dashboard_pins").doc(user.uid);
      const existing = await pinRef.get();
      if (existing.exists && existing.data()?.pinId === pinId) continue;

      await pinRef.set({
        type: "meal_reminder",
        message: body,
        severity: "info",
        foodSuggestion: null,
        pinId,
        createdAt: new Date(),
        dismissed: false,
      });

      const ok = await sendPush(user.fcmToken, {
        title: "FitAI — Meal reminder",
        body,
        type: "meal_reminder",
        pinId,
      });
      if (!ok) await pruneInvalidToken(user.uid);
    }
  },
);
