// ============================================================
// IMPORTANT: Replace this file with your actual Firebase config.
// Run: flutterfire configure
// This will generate the real firebase_options.dart for your project.
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCFlSP0nOIiMlyvwFhBoxgGLuBc5z6AAk',
    appId: '1:552703049298:web:87f68019148402a052698b',
    messagingSenderId: '552703049298',
    projectId: 'triozy-app',
    authDomain: 'triozy-app.firebaseapp.com',
    storageBucket: 'triozy-app.firebasestorage.app',
    measurementId: 'G-4G78RN338R',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNQkp9PIZrLPN36NgGIh_oK-XgdR5Tej4',
    appId: '1:552703049298:android:957656fc1388180b52698b',
    messagingSenderId: '552703049298',
    projectId: 'triozy-app',
    storageBucket: 'triozy-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBCFlSP0nOIiMlyvwFhBoxgGLuBc5z6AAk',
    appId: '1:552703049298:web:87f68019148402a052698b',
    messagingSenderId: '552703049298',
    projectId: 'triozy-app',
    storageBucket: 'triozy-app.firebasestorage.app',
    iosBundleId: 'com.example.triozyApp',
  );
}
