import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/firebase_options_staging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Environment Architecture & Isolation Tests', () {
    tearDown(DefaultFirebaseOptionsStaging.resetToUnconfigured);

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

    test(
      'Staging FirebaseOptions is unconfigured by default and fails closed',
      () {
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
      },
    );

    test(
      'Staging wrapper delegates properly when configured with valid options',
      () {
        const validStagingAndroid = FirebaseOptions(
          apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
          appId: '1:194789753908:android:a1b2c3d4e5f6',
          messagingSenderId: '194789753908',
          projectId: 'study-buddy-54266',
          storageBucket: 'study-buddy-54266.firebasestorage.app',
        );

        const validStagingIos = FirebaseOptions(
          apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
          appId: '1:194789753908:ios:f6e5d4c3b2a1',
          messagingSenderId: '194789753908',
          projectId: 'study-buddy-54266',
          storageBucket: 'study-buddy-54266.firebasestorage.app',
          iosBundleId: 'com.example.chatApp.staging',
        );

        DefaultFirebaseOptionsStaging.setMockConfiguredOptions(
          currentPlatform: validStagingAndroid,
          android: validStagingAndroid,
          ios: validStagingIos,
          expectedStorageBucket: 'study-buddy-54266.firebasestorage.app',
        );

        expect(DefaultFirebaseOptionsStaging.isConfigured, isTrue);
        expect(
          DefaultFirebaseOptionsStaging.currentPlatform.projectId,
          'study-buddy-54266',
        );
        expect(
          DefaultFirebaseOptionsStaging.android.messagingSenderId,
          '194789753908',
        );
        expect(
          DefaultFirebaseOptionsStaging.android.appId,
          '1:194789753908:android:a1b2c3d4e5f6',
        );
        expect(
          DefaultFirebaseOptionsStaging.ios.iosBundleId,
          'com.example.chatApp.staging',
        );
      },
    );

    test(
      'Staging rejects Production credentials and never marks configured',
      () {
        const invalidProductionAndroid = FirebaseOptions(
          apiKey: 'AIzaSyD67sj_ALe_vQU9-0B9-g0PpUEfQX2KGHI',
          appId: '1:639830188590:android:4a3b1c669d60ee593235bf',
          messagingSenderId: '639830188590',
          projectId: 'chat-app-28ac0',
          storageBucket: 'chat-app-28ac0.firebasestorage.app',
        );

        DefaultFirebaseOptionsStaging.setMockConfiguredOptions(
          android: invalidProductionAndroid,
          ios: DefaultFirebaseOptions.ios,
          expectedStorageBucket: 'study-buddy-54266.firebasestorage.app',
        );

        // Asserts that candidate injection cannot bypass pure validator
        expect(DefaultFirebaseOptionsStaging.isConfigured, isFalse);
        expect(
          () => DefaultFirebaseOptionsStaging.currentPlatform,
          throwsA(isA<UnconfiguredStagingEnvironmentException>()),
        );
      },
    );

    test(
      'Production options are completely independent of Staging options',
      () {
        expect(DefaultFirebaseOptions.android.projectId, 'chat-app-28ac0');
        expect(DefaultFirebaseOptions.ios.projectId, 'chat-app-28ac0');
        expect(
          DefaultFirebaseOptionsStaging.expectedProjectId,
          'study-buddy-54266',
        );
        expect(
          DefaultFirebaseOptionsStaging.expectedProjectNumber,
          '194789753908',
        );
      },
    );
  });
}
