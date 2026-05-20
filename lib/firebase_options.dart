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
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB-cFhPw-rhgcdhrAEtQws4SLNMktRuyfw',
    appId: '1:723944539541:android:4878f282d0b2b1c22b229c',
    messagingSenderId: '723944539541',
    projectId: 'palaoglu-14bf0',
    storageBucket: 'palaoglu-14bf0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDTbkTFPkVnkTscOJ8LAlEOaYt62WjXpNw',
    appId: '1:723944539541:ios:c234c16b987c0beb2b229c',
    messagingSenderId: '723944539541',
    projectId: 'palaoglu-14bf0',
    storageBucket: 'palaoglu-14bf0.firebasestorage.app',
    iosBundleId: 'com.palaoglu.kasatakip',
  );
}
