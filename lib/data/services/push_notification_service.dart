import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level background handler — must be a top-level or static function.
/// Firebase Messaging invokes this in an isolated background Dart isolate when
/// a data/notification message arrives while the app is terminated or in the
/// background. Keep it minimal: do not touch UI, do not trigger long work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM:bg] received messageId=${message.messageId}');
  // No further work needed — the OS already renders the notification when the
  // payload carries a `notification` block (sent by the Cloud Functions backend).
}

/// Wraps Firebase Cloud Messaging for FitAI.
///
/// Responsibilities:
///   1. Request notification permission (iOS + Android 13+)
///   2. Register the device FCM token to `users/{uid}.fcmToken`
///   3. Refresh the token in Firestore when FCM rotates it
///   4. Route foreground / background / terminated message events
///
/// Backend (Cloud Functions) is responsible for *sending* messages on schedule;
/// this client is only responsible for *receiving* them.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;

  /// Called once from main(), after Firebase.initializeApp().
  /// Sets up permission, background handler, and foreground listener.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Register background handler BEFORE requesting permission so messages
      // received during the permission prompt are not dropped.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await requestPermission();

      // Foreground messages: app is open in the foreground when push arrives.
      // The OS does NOT auto-display a banner in this case — it is up to the
      // app to surface it. We log it; the dashboard's pin listener already
      // shows the same content via Firestore so no further UI work is needed.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM:fg] type=${message.data['type']} '
          'title=${message.notification?.title}',
        );
      });

      // Tap on a notification while the app is in the background:
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM:tap] type=${message.data['type']}');
        // Navigation is handled by the consuming UI layer (e.g. SplashScreen
        // reads getInitialMessage on cold start).
      });
    } catch (e, st) {
      // Some emulator configurations lack Google Play services and crash on
      // FCM init. Swallow so the app still starts; notifications just won't fire.
      debugPrint('[FCM] init failed: $e\n$st');
    }
  }

  /// Requests notification permission.
  /// iOS: always shows the system prompt the first time.
  /// Android 13+: shows the runtime POST_NOTIFICATIONS prompt.
  /// Older Android: granted by default.
  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint(
      '[FCM] permission=${settings.authorizationStatus.name}',
    );
    return settings;
  }

  /// Registers the device's FCM token to `users/{uid}.fcmToken`.
  /// Idempotent — safe to call on every app start and after sign-in.
  /// Also subscribes to token-refresh updates so Firestore stays current.
  Future<void> registerToken(String uid) async {
    if (uid.isEmpty) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FCM] getToken returned null — likely missing Play Services');
        return;
      }
      await _writeToken(uid, token);

      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] token refreshed for uid=$uid');
        await _writeToken(uid, newToken);
      });
    } catch (e, st) {
      debugPrint('[FCM] registerToken failed: $e\n$st');
    }
  }

  /// Removes the FCM token for a user — call on sign-out so a logged-out
  /// device does not keep receiving pushes intended for the previous user.
  Future<void> unregisterToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('[FCM] unregisterToken failed: $e');
    }
  }

  /// Returns the message that opened the app from a terminated state, if any.
  /// Called by SplashScreen on cold start so it can navigate to the right
  /// screen (chat, plan, dashboard) based on the notification payload.
  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await _messaging.getInitialMessage();
    } catch (e) {
      debugPrint('[FCM] getInitialMessage failed: $e');
      return null;
    }
  }

  Future<void> _writeToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('[FCM] token stored for uid=$uid');
  }
}
