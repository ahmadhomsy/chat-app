import 'package:chat_app/firebase_options.dart' as prod;
import 'package:chat_app/firebase_options_staging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Staging FirebaseOptions Pure Validator Tests', () {
    const validExpectedBucket = 'study-buddy-54266.firebasestorage.app';

    const validAndroidOptions = FirebaseOptions(
      apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
      appId: '1:194789753908:android:a1b2c3d4e5f6',
      messagingSenderId: '194789753908',
      projectId: 'study-buddy-54266',
      storageBucket: validExpectedBucket,
    );

    const validIosOptions = FirebaseOptions(
      apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
      appId: '1:194789753908:ios:f6e5d4c3b2a1',
      messagingSenderId: '194789753908',
      projectId: 'study-buddy-54266',
      storageBucket: validExpectedBucket,
      iosBundleId: 'com.example.chatApp.staging',
    );

    test('1. Correct Staging Android and iOS options pass validation', () {
      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isTrue, reason: res.errorMessage);
      expect(res.errorMessage, isNull);
    });

    test('2. Production Android options fail validation', () {
      final res = validateStagingOptions(
        android: prod.DefaultFirebaseOptions.android,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, isNotNull);
    });

    test('3. Production iOS options fail validation', () {
      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: prod.DefaultFirebaseOptions.ios,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, isNotNull);
    });

    test('4. Wrong project ID fails validation', () {
      const wrongProjectAndroid = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
        appId: '1:194789753908:android:a1b2c3d4e5f6',
        messagingSenderId: '194789753908',
        projectId: 'wrong-project-id',
        storageBucket: validExpectedBucket,
      );

      final res = validateStagingOptions(
        android: wrongProjectAndroid,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('projectId'));
    });

    test('5. Wrong project number fails validation', () {
      const wrongSenderAndroid = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
        appId: '1:194789753908:android:a1b2c3d4e5f6',
        messagingSenderId: '999999999999',
        projectId: 'study-buddy-54266',
        storageBucket: validExpectedBucket,
      );

      final res = validateStagingOptions(
        android: wrongSenderAndroid,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('messagingSenderId'));
    });

    test('6. Wrong Android App ID platform fails validation', () {
      const wrongPlatformAndroid = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
        appId: '1:194789753908:ios:a1b2c3d4e5f6',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: validExpectedBucket,
      );

      final res = validateStagingOptions(
        android: wrongPlatformAndroid,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Android appId'));
    });

    test('7. Wrong iOS App ID platform fails validation', () {
      const wrongPlatformIos = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
        appId: '1:194789753908:android:f6e5d4c3b2a1',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: validExpectedBucket,
        iosBundleId: 'com.example.chatApp.staging',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: wrongPlatformIos,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('iOS appId'));
    });

    test('8. Wrong iOS bundle ID fails validation', () {
      const wrongBundleIos = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
        appId: '1:194789753908:ios:f6e5d4c3b2a1',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: validExpectedBucket,
        iosBundleId: 'com.example.chatApp.wrong',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: wrongBundleIos,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('bundleId'));
    });

    test('9. Empty API key fails validation', () {
      const emptyKeyAndroid = FirebaseOptions(
        apiKey: '',
        appId: '1:194789753908:android:a1b2c3d4e5f6',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: validExpectedBucket,
      );

      final res = validateStagingOptions(
        android: emptyKeyAndroid,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('apiKey'));
    });

    test('10. Placeholder API key fails validation', () {
      const placeholderKeyIos = FirebaseOptions(
        apiKey: 'STAGING_IOS_API_KEY_PLACEHOLDER',
        appId: '1:194789753908:ios:f6e5d4c3b2a1',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: validExpectedBucket,
        iosBundleId: 'com.example.chatApp.staging',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: placeholderKeyIos,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('apiKey'));
    });

    test('11. Production Storage Bucket fails validation', () {
      const prodBucketAndroid = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
        appId: '1:194789753908:android:a1b2c3d4e5f6',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: 'chat-app-28ac0.firebasestorage.app',
      );

      final res = validateStagingOptions(
        android: prodBucketAndroid,
        ios: validIosOptions,
        expectedStorageBucket: 'chat-app-28ac0.firebasestorage.app',
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Production storage bucket'));
    });

    test('12. Unknown or empty Storage Bucket fails validation', () {
      final resNull = validateStagingOptions(
        android: validAndroidOptions,
        ios: validIosOptions,
        expectedStorageBucket: null,
      );
      expect(resNull.isValid, isFalse);
      expect(resNull.errorMessage, contains('Storage Bucket is unknown'));

      final resEmpty = validateStagingOptions(
        android: validAndroidOptions,
        ios: validIosOptions,
        expectedStorageBucket: '',
      );
      expect(resEmpty.isValid, isFalse);
    });

    test('13. Correct Staging Storage Bucket passes validation', () {
      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: validIosOptions,
        expectedStorageBucket: validExpectedBucket,
      );
      expect(res.isValid, isTrue);
      expect(res.errorMessage, isNull);
    });
  });

  group('DefaultFirebaseOptionsStaging Wrapper Safety & Fail-Closed Tests', () {
    tearDown(DefaultFirebaseOptionsStaging.resetToUnconfigured);

    test(
      'Candidate injection with Production credentials fails validation and never marks configured',
      () {
        DefaultFirebaseOptionsStaging.setMockConfiguredOptions(
          currentPlatform: prod.DefaultFirebaseOptions.android,
          android: prod.DefaultFirebaseOptions.android,
          ios: prod.DefaultFirebaseOptions.ios,
          expectedStorageBucket: 'study-buddy-54266.firebasestorage.app',
        );

        // Validation fails because production credentials cannot bypass the validator
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
      'Candidate injection with valid Staging credentials and bucket marks configured',
      () {
        const validBucket = 'study-buddy-54266.firebasestorage.app';

        const validAndroid = FirebaseOptions(
          apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
          appId: '1:194789753908:android:a1b2c3d4e5f6',
          messagingSenderId: '194789753908',
          projectId: 'study-buddy-54266',
          storageBucket: validBucket,
        );

        const validIos = FirebaseOptions(
          apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
          appId: '1:194789753908:ios:f6e5d4c3b2a1',
          messagingSenderId: '194789753908',
          projectId: 'study-buddy-54266',
          storageBucket: validBucket,
          iosBundleId: 'com.example.chatApp.staging',
        );

        DefaultFirebaseOptionsStaging.setMockConfiguredOptions(
          currentPlatform: validAndroid,
          android: validAndroid,
          ios: validIos,
          expectedStorageBucket: validBucket,
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
          DefaultFirebaseOptionsStaging.ios.iosBundleId,
          'com.example.chatApp.staging',
        );
      },
    );
  });
}
