import {db, admin} from "./admin";

export interface ActiveUser {
  uid: string;
  fcmToken: string;
  name: string;
  goals: string[];
  conditions: string[];
  dailyCalorieGoal: number;
  dietaryPreference: string;
}

/**
 * Returns every user that has finished onboarding AND has a registered
 * FCM token. Scheduled functions iterate this list and push to each device.
 *
 * Filtering at query time keeps the loop tight even at scale.
 */
export async function listPushEligibleUsers(): Promise<ActiveUser[]> {
  const snap = await db
    .collection("users")
    .where("onboardingComplete", "==", true)
    .get();

  const users: ActiveUser[] = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const token = data.fcmToken as string | undefined;
    if (!token) continue;
    users.push({
      uid: doc.id,
      fcmToken: token,
      name: (data.name as string) ?? "",
      goals: (data.goals as string[]) ?? [],
      conditions: (data.conditions as string[]) ?? [],
      dailyCalorieGoal: (data.dailyCalorieGoal as number) ?? 2000,
      dietaryPreference: (data.dietaryPreference as string) ?? "Classic",
    });
  }
  return users;
}

/**
 * Removes a stale FCM token from a user's profile so we stop targeting
 * uninstalled / signed-out devices.
 */
export async function pruneInvalidToken(uid: string): Promise<void> {
  await db.collection("users").doc(uid).update({
    fcmToken: admin.firestore.FieldValue.delete(),
    fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
  });
}
