// Replace this file by running:
// flutterfire configure
//
// The placeholder values below keep the project compilable before Firebase
// credentials are generated. Real authentication and Firestore access require
// the generated values from your Firebase project.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkww4LS4_XObxhDaZdliUH3xeEygvazWc',
    appId: '1:723944539541:web:adc825bb2bc4afc82b229c',
    messagingSenderId: '723944539541',
    projectId: 'palaoglu-14bf0',
    authDomain: 'palaoglu-14bf0.firebaseapp.com',
    storageBucket: 'palaoglu-14bf0.firebasestorage.app',
    measurementId: 'G-G8L5JP0VP1',
  );
}
