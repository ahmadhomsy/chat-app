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

    test('Staging FirebaseOptions is unconfigured and fails closed', () {
      expect(DefaultFirebaseOptionsStaging.isConfigured, isFalse);

      expect(
        () => DefaultFirebaseOptionsStaging.currentPlatform,
        throwsA(isA<UnconfiguredStagingEnvironmentException>()),
      );
      expect(
        () => DefaultFirebaseOptionsStaging.android,
        throwsA(isA<UnconfiguredStagingEnvironmentException>()),
      );
      expect(
        () => DefaultFirebaseOptionsStaging.ios,
        throwsA(isA<UnconfiguredStagingEnvironmentException>()),
      );
    });

    test(
      'Production options are not affected by unconfigured Staging options',
      () {
        expect(DefaultFirebaseOptions.android.projectId, 'chat-app-28ac0');
        expect(DefaultFirebaseOptions.ios.projectId, 'chat-app-28ac0');
      },
    );
  });
}
