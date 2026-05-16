import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {db} from "../admin";
import {listPushEligibleUsers, pruneInvalidToken} from "../users";
import {sendPush} from "../messaging";

/**
 * Weekly Review — Sunday 21:00 Africa/Tunis (cron weekday=0).
 *
 * Notifies the user that next week's plan has been adapted from this
 * week's behaviour. The actual plan-adaptation work happens on-device
 * in the orchestrator when the app next opens; this push prompts the user
 * to open the app and trigger that flow.
 */
export const weeklyReview = onSchedule(
  {
    schedule: "0 21 * * 0",
    timeZone: "Africa/Tunis",
    region: "europe-west1",
  },
  async () => {
    const users = await listPushEligibleUsers();
    logger.info("weeklyReview: tick", {userCount: users.length});

    for (const user of users) {
      const firstName = user.name.split(" ")[0] || "there";
      const message =
        `${firstName}, your week is in. Tap to see your adapted plan ` +
        `for the next 7 days, tuned to what you actually ate.`;
      const pinId = `weekly_${new Date().toISOString().slice(0, 10)}`;

      await db.collection("dashboard_pins").doc(user.uid).set({
        type: "weekly_review",
        message,
        severity: "info",
        foodSuggestion: null,
        pinId,
        createdAt: new Date(),
        dismissed: false,
      });

      const ok = await sendPush(user.fcmToken, {
        title: "FitAI — Weekly review ready",
        body: message,
        type: "weekly_review",
        pinId,
      });
      if (!ok) await pruneInvalidToken(user.uid);
    }
  },
);
