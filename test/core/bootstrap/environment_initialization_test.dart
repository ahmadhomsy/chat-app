import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/firebase_options_staging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Environment Architecture & Isolation Tests', () {
    test('Production FirebaseOptions targets chat-app-28ac0 exclusively', () {
      expect(DefaultFirebaseOptions.android.projectId, 'chat-app-28ac0');
      expect(DefaultFirebaseOptions.android.messagingSenderId, '639830188590');
      expect(
        DefaultFirebaseOptions.android.storageBucket,
        'chat-app-28ac0.firebasestorage.app',
      );

      expect(DefaultFirebaseOptions.ios.projectId, 'chat-app-28ac0');
      expect(DefaultFirebaseOptions.ios.messagingSenderId, '639830188590');
      expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.example.chatApp');
    });

    test('Staging FirebaseOptions targets study-buddy-54266 exclusively', () {
      expect(
        DefaultFirebaseOptionsStaging.android.projectId,
        'study-buddy-54266',
      );
      expect(
        DefaultFirebaseOptionsStaging.android.messagingSenderId,
        '194789753908',
      );
      expect(
        DefaultFirebaseOptionsStaging.android.storageBucket,
        'study-buddy-54266.firebasestorage.app',
      );

      expect(DefaultFirebaseOptionsStaging.ios.projectId, 'study-buddy-54266');
      expect(
        DefaultFirebaseOptionsStaging.ios.messagingSenderId,
        '194789753908',
      );
      expect(
        DefaultFirebaseOptionsStaging.ios.iosBundleId,
        'com.example.chatApp.staging',
      );
    });

    test('Production and Staging have completely independent resources', () {
      expect(
        DefaultFirebaseOptions.android.projectId,
        isNot(equals(DefaultFirebaseOptionsStaging.android.projectId)),
      );
      expect(
        DefaultFirebaseOptions.android.messagingSenderId,
        isNot(equals(DefaultFirebaseOptionsStaging.android.messagingSenderId)),
      );
      expect(
        DefaultFirebaseOptions.android.storageBucket,
        isNot(equals(DefaultFirebaseOptionsStaging.android.storageBucket)),
      );
      expect(
        DefaultFirebaseOptions.ios.iosBundleId,
        isNot(equals(DefaultFirebaseOptionsStaging.ios.iosBundleId)),
      );
    });
  });
}
