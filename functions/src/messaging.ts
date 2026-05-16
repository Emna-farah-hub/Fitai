import {messaging} from "./admin";
import * as logger from "firebase-functions/logger";

export interface PushPayload {
  /** Notification title (lock-screen headline). */
  title: string;
  /** Notification body (lock-screen content). */
  body: string;
  /**
   * Routing intent — read by the Flutter client to navigate to the right
   * screen on tap. Examples: "chat", "plan", "dashboard", "weekly_review".
   */
  type: string;
  /** Optional message id pinned by the orchestrator, used for deduplication. */
  pinId?: string;
}

/**
 * Sends a single FCM push to a device token.
 * Returns true on success, false on a non-recoverable error (invalid token).
 */
export async function sendPush(
  token: string,
  payload: PushPayload,
): Promise<boolean> {
  try {
    await messaging.send({
      token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        type: payload.type,
        pinId: payload.pinId ?? "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "fitai_default",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "content-available": 1,
          },
        },
      },
    });
    return true;
  } catch (err) {
    const code = (err as {code?: string}).code ?? "unknown";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      logger.warn("FCM token invalid, will be pruned", {token, code});
      return false;
    }
    logger.error("FCM send failed", {token, code, err});
    return false;
  }
}
