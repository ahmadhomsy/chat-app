// File generated for ChatUp Local Demo Environment (Zero Billing).
// Target Firebase Project: demo-chatup
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the isolated local development demo environment.
///
/// Targets the offline Firebase Emulator Suite with local demo project ID 'demo-chatup'.
/// This configuration never incurs billing, never accesses real cloud resources,
/// and is completely isolated from Production (chat-app-28ac0) and Staging (study-buddy-54266).
class DefaultFirebaseOptionsDevelopment {
  static const String demoProjectId = 'demo-chatup';
  static const String demoProjectNumber = '100000000000';
  static const String demoStorageBucket = 'demo-chatup.appspot.com';
  static const String demoApiKey = 'AIzaSyDemoChatUpLocalEmulatorDummyKey';

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
          'DefaultFirebaseOptionsDevelopment are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: demoApiKey,
    appId: '1:$demoProjectNumber:web:development000000000',
    messagingSenderId: demoProjectNumber,
    projectId: demoProjectId,
    authDomain: '$demoProjectId.firebaseapp.com',
    storageBucket: demoStorageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: demoApiKey,
    appId: '1:$demoProjectNumber:android:development000000000',
    messagingSenderId: demoProjectNumber,
    projectId: demoProjectId,
    storageBucket: demoStorageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: demoApiKey,
    appId: '1:$demoProjectNumber:ios:development000000000',
    messagingSenderId: demoProjectNumber,
    projectId: demoProjectId,
    storageBucket: demoStorageBucket,
    iosBundleId: 'com.example.chatApp.dev',
  );
}
