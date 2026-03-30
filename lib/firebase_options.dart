// IMPORTANT: Replace these placeholder values with your real Firebase config.
// Run `flutterfire configure` in your project root to auto-generate this file
// after setting up your Firebase project at https://console.firebase.google.com
//
// Steps:
//   1. Install flutterfire_cli: dart pub global activate flutterfire_cli
//   2. Login: firebase login
//   3. Configure: flutterfire configure
//   This will overwrite this file with your real keys.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── REPLACE ALL VALUES BELOW WITH YOUR REAL FIREBASE CONFIG ──────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTSNVeEFJJhK-uDanAdvFy4RM5bT4r304',
    appId: '1:168985974483:android:9d7721cff03800f9872626',
    messagingSenderId: '168985974483',
    projectId: 'fitai-78348',
    storageBucket: 'fitai-78348.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBvTy6EmCqYsAojklkqFkVt61isR7iabk',
    appId: '1:168985974483:ios:9817cdccf64714b0872626',
    messagingSenderId: '168985974483',
    projectId: 'fitai-78348',
    storageBucket: 'fitai-78348.firebasestorage.app',
    iosBundleId: 'com.fitai.fitai',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-fitai-project-id',
    storageBucket: 'your-fitai-project-id.appspot.com',
    authDomain: 'your-fitai-project-id.firebaseapp.com',
  );
}