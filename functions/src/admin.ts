import * as admin from "firebase-admin";

/**
 * Singleton Firebase Admin initialiser.
 * Cloud Functions auto-detect credentials in the runtime; locally,
 * GOOGLE_APPLICATION_CREDENTIALS points at a service-account JSON.
 */
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const messaging = admin.messaging();
export {admin};
