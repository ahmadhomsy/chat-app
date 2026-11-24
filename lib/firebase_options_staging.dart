// File generated for ChatUp Staging Environment.
// Target Firebase Project: study-buddy-54266 (Project Number: 194789753908)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for ChatUp Staging environment (`study-buddy-54266`).
///
/// Example:
/// ```dart
/// import 'firebase_options_staging.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptionsStaging.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptionsStaging {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptionsStaging have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptionsStaging have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptionsStaging have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptionsStaging have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptionsStaging are not supported for this platform.',
        );
    }
  }

  // Staging Android configuration for study-buddy-54266 (Project Number: 194789753908)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'STAGING_ANDROID_API_KEY_PLACEHOLDER',
    appId: '1:194789753908:android:staging_chat_app_app_id',
    messagingSenderId: '194789753908',
    projectId: 'study-buddy-54266',
    storageBucket: 'study-buddy-54266.firebasestorage.app',
  );

  // Staging iOS configuration for study-buddy-54266 (Project Number: 194789753908)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'STAGING_IOS_API_KEY_PLACEHOLDER',
    appId: '1:194789753908:ios:staging_chat_app_app_id',
    messagingSenderId: '194789753908',
    projectId: 'study-buddy-54266',
    storageBucket: 'study-buddy-54266.firebasestorage.app',
    iosBundleId: 'com.example.chatApp.staging',
  );
}
