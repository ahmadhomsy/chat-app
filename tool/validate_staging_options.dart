import 'dart:io' show Platform;
import 'package:chat_app/firebase_options_staging.dart';
import 'package:chat_app/firebase_options_staging.generated.dart' as generated;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Deterministic Staging FirebaseOptions Identity & Independent Bucket Verification',
    () {
      // Sourced independently from environment, never from android.storageBucket itself
      const dartDefineBucket = String.fromEnvironment(
        'EXPECTED_STAGING_STORAGE_BUCKET',
      );
      final envBucket = Platform.environment['EXPECTED_STAGING_STORAGE_BUCKET'];
      final expectedBucket = dartDefineBucket.isNotEmpty
          ? dartDefineBucket
          : (envBucket ?? '');

      expect(
        expectedBucket.trim().isNotEmpty,
        isTrue,
        reason:
            'Mandatory expected Staging storage bucket is missing or empty. '
            'Pass EXPECTED_STAGING_STORAGE_BUCKET via environment variable or --dart-define.',
      );

      expect(
        expectedBucket,
        isNot(equals('chat-app-28ac0.firebasestorage.app')),
        reason: 'Authoritative Staging bucket cannot be Production bucket',
      );
      expect(
        expectedBucket,
        isNot(equals('chat-app-28ac0.appspot.com')),
        reason: 'Authoritative Staging bucket cannot be Production bucket',
      );

      final android = generated.DefaultFirebaseOptions.android;
      final ios = generated.DefaultFirebaseOptions.ios;

      // 1. Project ID must be strictly study-buddy-54266
      expect(
        android.projectId,
        'study-buddy-54266',
        reason: 'Staging Android options must target project study-buddy-54266',
      );
      expect(
        ios.projectId,
        'study-buddy-54266',
        reason: 'Staging iOS options must target project study-buddy-54266',
      );

      // 2. Messaging Sender ID must be strictly 194789753908
      expect(
        android.messagingSenderId,
        '194789753908',
        reason:
            'Staging Android messagingSenderId must match project number 194789753908',
      );
      expect(
        ios.messagingSenderId,
        '194789753908',
        reason:
            'Staging iOS messagingSenderId must match project number 194789753908',
      );

      // 3. Android App ID belongs to project 194789753908 and is an Android app
      expect(
        android.appId.startsWith('1:194789753908:android:'),
        isTrue,
        reason:
            'android.appId must belong to project 194789753908 and start with 1:194789753908:android:',
      );

      // 4. iOS App ID belongs to project 194789753908 and is an iOS app
      expect(
        ios.appId.startsWith('1:194789753908:ios:'),
        isTrue,
        reason:
            'ios.appId must belong to project 194789753908 and start with 1:194789753908:ios:',
      );

      // 5. iOS Bundle ID must match com.example.chatApp.staging
      expect(
        ios.iosBundleId,
        'com.example.chatApp.staging',
        reason: 'ios.iosBundleId must be com.example.chatApp.staging',
      );

      // 6. Independent Storage Bucket Identity Checks: verify options equal expected bucket
      expect(
        android.storageBucket,
        isNotNull,
        reason: 'android.storageBucket cannot be null',
      );
      expect(
        android.storageBucket!.isNotEmpty,
        isTrue,
        reason: 'android.storageBucket cannot be empty',
      );
      expect(
        android.storageBucket,
        equals(expectedBucket),
        reason:
            'android.storageBucket must match independently supplied expected bucket',
      );

      expect(
        ios.storageBucket,
        isNotNull,
        reason: 'ios.storageBucket cannot be null',
      );
      expect(
        ios.storageBucket!.isNotEmpty,
        isTrue,
        reason: 'ios.storageBucket cannot be empty',
      );
      expect(
        ios.storageBucket,
        equals(expectedBucket),
        reason:
            'ios.storageBucket must match independently supplied expected bucket',
      );

      // Android and iOS buckets must strictly match each other
      expect(
        android.storageBucket,
        equals(ios.storageBucket),
        reason: 'Android and iOS storage buckets must match each other',
      );

      // 7. Absolute Production Isolation Check: verify no production credentials exist
      expect(android.projectId, isNot(equals('chat-app-28ac0')));
      expect(ios.projectId, isNot(equals('chat-app-28ac0')));
      expect(android.messagingSenderId, isNot(equals('639830188590')));
      expect(ios.messagingSenderId, isNot(equals('639830188590')));
      expect(android.appId, isNot(contains('639830188590')));
      expect(ios.appId, isNot(contains('639830188590')));
      expect(
        android.storageBucket,
        isNot(equals('chat-app-28ac0.firebasestorage.app')),
      );
      expect(
        android.storageBucket,
        isNot(equals('chat-app-28ac0.appspot.com')),
      );
      expect(
        ios.storageBucket,
        isNot(equals('chat-app-28ac0.firebasestorage.app')),
      );
      expect(
        ios.storageBucket,
        isNot(equals('chat-app-28ac0.appspot.com')),
      );

      // 8. Non-empty, non-placeholder API keys
      expect(android.apiKey.isNotEmpty, isTrue);
      expect(android.apiKey, isNot(contains('PLACEHOLDER')));
      expect(ios.apiKey.isNotEmpty, isTrue);
      expect(ios.apiKey, isNot(contains('PLACEHOLDER')));

      // 9. Pure validateStagingOptions must validate options cleanly with expected bucket
      final valRes = validateStagingOptions(
        android: android,
        ios: ios,
        expectedStorageBucket: expectedBucket,
      );
      expect(valRes.isValid, isTrue, reason: valRes.errorMessage);
    },
  );
}
