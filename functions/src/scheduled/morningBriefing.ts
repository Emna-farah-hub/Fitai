import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {db} from "../admin";
import {listPushEligibleUsers, pruneInvalidToken} from "../users";
import {sendPush} from "../messaging";

/**
 * Morning Briefing — fires every day at 08:00 Africa/Tunis.
 *
 * Pushes a personalised "good morning" notification and pins the same
 * message to the user's dashboard so the in-app view is in sync when they
 * open the app.
 */
export const morningBriefing = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Africa/Tunis",
    region: "europe-west1",
  },
  async () => {
    const users = await listPushEligibleUsers();
    logger.info("morningBriefing: tick", {userCount: users.length});

    for (const user of users) {
      const firstName = user.name.split(" ")[0] || "there";
      const greeting =
        `Good morning, ${firstName}! Your day starts with ` +
        `${user.dailyCalorieGoal} kcal to spend wisely.`;
      const pinId = `morning_${new Date().toISOString().slice(0, 10)}`;

      // Pin the message to the dashboard first so the in-app view is in sync
      // even if FCM delivery is delayed.
      await db.collection("dashboard_pins").doc(user.uid).set({
        type: "morning_briefing",
        message: greeting,
        severity: "info",
        foodSuggestion: null,
        pinId,
        createdAt: new Date(),
        dismissed: false,
      });

      const ok = await sendPush(user.fcmToken, {
        title: "FitAI — Morning briefing",
        body: greeting,
        type: "morning_briefing",
        pinId,
      });
      if (!ok) await pruneInvalidToken(user.uid);
    }
  },
);
