import 'package:chat_app/firebase_options.dart' as prod;
import 'package:chat_app/firebase_options_staging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Staging FirebaseOptions Pure Validator Tests', () {
    // Synthetic fixture values clearly identified for unit testing only
    const syntheticExpectedBucket = 'study-buddy-54266.firebasestorage.app';

    const validAndroidOptions = FirebaseOptions(
      apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
      appId: '1:194789753908:android:a1b2c3d4e5f6',
      messagingSenderId: '194789753908',
      projectId: 'study-buddy-54266',
      storageBucket: syntheticExpectedBucket,
    );

    const validIosOptions = FirebaseOptions(
      apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
      appId: '1:194789753908:ios:f6e5d4c3b2a1',
      messagingSenderId: '194789753908',
      projectId: 'study-buddy-54266',
      storageBucket: syntheticExpectedBucket,
      iosBundleId: 'com.example.chatApp.staging',
    );

    test('1. Correct Staging Android and iOS options pass validation', () {
      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isTrue, reason: res.errorMessage);
      expect(res.errorMessage, isNull);
    });

    test('2. Production Android options fail validation', () {
      final res = validateStagingOptions(
        android: prod.DefaultFirebaseOptions.android,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, isNotNull);
    });

    test('3. Production iOS options fail validation', () {
      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: prod.DefaultFirebaseOptions.ios,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
      );

      final res = validateStagingOptions(
        android: wrongProjectAndroid,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
      );

      final res = validateStagingOptions(
        android: wrongSenderAndroid,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
      );

      final res = validateStagingOptions(
        android: wrongPlatformAndroid,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
        iosBundleId: 'com.example.chatApp.staging',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: wrongPlatformIos,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
        iosBundleId: 'com.example.chatApp.wrong',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: wrongBundleIos,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
      );

      final res = validateStagingOptions(
        android: emptyKeyAndroid,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
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
        storageBucket: syntheticExpectedBucket,
        iosBundleId: 'com.example.chatApp.staging',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: placeholderKeyIos,
        expectedStorageBucket: syntheticExpectedBucket,
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
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isTrue);
      expect(res.errorMessage, isNull);
    });

    test('14. Mismatched Android Storage Bucket fails validation', () {
      const mismatchedAndroid = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
        appId: '1:194789753908:android:a1b2c3d4e5f6',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: 'other-bucket.appspot.com',
      );

      final res = validateStagingOptions(
        android: mismatchedAndroid,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Android storageBucket'));
    });

    test('15. Mismatched iOS Storage Bucket fails validation', () {
      const mismatchedIos = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
        appId: '1:194789753908:ios:f6e5d4c3b2a1',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        storageBucket: 'other-bucket.appspot.com',
        iosBundleId: 'com.example.chatApp.staging',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: mismatchedIos,
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('iOS storageBucket'));
    });

    test('16. Null or empty Android storageBucket fails validation', () {
      const nullBucketAndroid = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
        appId: '1:194789753908:android:a1b2c3d4e5f6',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
      );

      final res = validateStagingOptions(
        android: nullBucketAndroid,
        ios: validIosOptions,
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Android storageBucket'));
    });

    test('17. Null or empty iOS storageBucket fails validation', () {
      const nullBucketIos = FirebaseOptions(
        apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
        appId: '1:194789753908:ios:f6e5d4c3b2a1',
        messagingSenderId: '194789753908',
        projectId: 'study-buddy-54266',
        iosBundleId: 'com.example.chatApp.staging',
      );

      final res = validateStagingOptions(
        android: validAndroidOptions,
        ios: nullBucketIos,
        expectedStorageBucket: syntheticExpectedBucket,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('iOS storageBucket'));
    });
  });

  group(
    'DefaultFirebaseOptionsStaging Runtime Boundary & Anti-Bypass Regression Tests',
    () {
      test(
        'authoritativeStorageBucket == null strictly guarantees fail-closed behavior at runtime',
        () {
          expect(
            DefaultFirebaseOptionsStaging.authoritativeStorageBucket,
            isNull,
          );
          expect(DefaultFirebaseOptionsStaging.isConfigured, isFalse);
          expect(
            DefaultFirebaseOptionsStaging.validation.isValid,
            isFalse,
          );
          expect(
            DefaultFirebaseOptionsStaging.validation.errorMessage,
            contains('Authoritative Staging Storage Bucket is null'),
          );

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
        'No runtime injection path exists: external candidate options cannot alter wrapper state',
        () {
          // Creating independent options (even valid Staging ones with Production currentPlatform)
          // has zero effect on DefaultFirebaseOptionsStaging.
          const candidateAndroid = FirebaseOptions(
            apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_123',
            appId: '1:194789753908:android:a1b2c3d4e5f6',
            messagingSenderId: '194789753908',
            projectId: 'study-buddy-54266',
            storageBucket: 'study-buddy-54266.firebasestorage.app',
          );

          const candidateIos = FirebaseOptions(
            apiKey: 'AIzaSy_VALID_STAGING_KEY_FOR_TESTS_456',
            appId: '1:194789753908:ios:f6e5d4c3b2a1',
            messagingSenderId: '194789753908',
            projectId: 'study-buddy-54266',
            storageBucket: 'study-buddy-54266.firebasestorage.app',
            iosBundleId: 'com.example.chatApp.staging',
          );

          // Validation of standalone candidates succeeds with pure validator
          final val = validateStagingOptions(
            android: candidateAndroid,
            ios: candidateIos,
            expectedStorageBucket: 'study-buddy-54266.firebasestorage.app',
          );
          expect(val.isValid, isTrue);

          // But runtime DefaultFirebaseOptionsStaging remains completely untouched, immutable, and fail-closed
          expect(DefaultFirebaseOptionsStaging.isConfigured, isFalse);
          expect(
            () => DefaultFirebaseOptionsStaging.currentPlatform,
            throwsA(isA<UnconfiguredStagingEnvironmentException>()),
          );
        },
      );
    },
  );
}
