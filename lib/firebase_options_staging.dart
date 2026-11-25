// Wrapper for ChatUp Staging Environment Firebase Options.
// Target Firebase Project: study-buddy-54266 (Project Number: 194789753908)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'firebase_options_staging.generated.dart' as generated;

/// Exception thrown when the Staging environment is executed prior to real
/// Firebase App registration and authoritative storage bucket verification in study-buddy-54266.
class UnconfiguredStagingEnvironmentException implements Exception {
  final String message;
  const UnconfiguredStagingEnvironmentException([
    this.message =
        'ChatUp Staging environment is pending live Firebase App registration in project study-buddy-54266 (Project Number: 194789753908). '
        'Real Firebase configuration options must be generated via FlutterFire CLI once the authorized IAM account completes app registration, '
        'and the authoritative Staging Storage Bucket must be verified.',
  ]);

  @override
  String toString() => 'UnconfiguredStagingEnvironmentException: $message';
}

/// Result object for Staging FirebaseOptions identity validation.
class StagingConfigurationValidation {
  final bool isValid;
  final String? errorMessage;

  const StagingConfigurationValidation.valid()
    : isValid = true,
      errorMessage = null;

  const StagingConfigurationValidation.invalid(this.errorMessage)
    : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $errorMessage';
}

/// Pure validation function shared between runtime checks and automated tests.
/// Asserts strict Staging project identity, platform app IDs, bundle ID,
/// non-placeholder API keys, and authoritative Storage Bucket identity.
/// Rejects all Production credentials.
StagingConfigurationValidation validateStagingOptions({
  required FirebaseOptions android,
  required FirebaseOptions ios,
  required String? expectedStorageBucket,
}) {
  // 1. Authoritative Storage Bucket must be known, non-empty, and non-production
  if (expectedStorageBucket == null || expectedStorageBucket.trim().isEmpty) {
    return const StagingConfigurationValidation.invalid(
      'Authoritative Staging Storage Bucket is unknown or empty. Staging remains unconfigured until authoritative bucket is verified after IAM access is restored.',
    );
  }

  if (expectedStorageBucket == 'chat-app-28ac0.firebasestorage.app' ||
      expectedStorageBucket == 'chat-app-28ac0.appspot.com') {
    return const StagingConfigurationValidation.invalid(
      'Expected storage bucket cannot match Production storage bucket.',
    );
  }

  // 2. Project ID validation: must strictly match study-buddy-54266
  if (android.projectId != DefaultFirebaseOptionsStaging.expectedProjectId) {
    return StagingConfigurationValidation.invalid(
      'Android projectId "${android.projectId}" must match expected "${DefaultFirebaseOptionsStaging.expectedProjectId}".',
    );
  }
  if (ios.projectId != DefaultFirebaseOptionsStaging.expectedProjectId) {
    return StagingConfigurationValidation.invalid(
      'iOS projectId "${ios.projectId}" must match expected "${DefaultFirebaseOptionsStaging.expectedProjectId}".',
    );
  }

  // 3. Sender ID validation: must strictly match 194789753908
  if (android.messagingSenderId !=
      DefaultFirebaseOptionsStaging.expectedProjectNumber) {
    return StagingConfigurationValidation.invalid(
      'Android messagingSenderId "${android.messagingSenderId}" must match expected "${DefaultFirebaseOptionsStaging.expectedProjectNumber}".',
    );
  }
  if (ios.messagingSenderId !=
      DefaultFirebaseOptionsStaging.expectedProjectNumber) {
    return StagingConfigurationValidation.invalid(
      'iOS messagingSenderId "${ios.messagingSenderId}" must match expected "${DefaultFirebaseOptionsStaging.expectedProjectNumber}".',
    );
  }

  // 4. Android App ID must belong to project 194789753908 and be android platform
  if (!android.appId.startsWith(
    '1:${DefaultFirebaseOptionsStaging.expectedProjectNumber}:android:',
  )) {
    return StagingConfigurationValidation.invalid(
      'Android appId "${android.appId}" must match prefix "1:${DefaultFirebaseOptionsStaging.expectedProjectNumber}:android:".',
    );
  }

  // 5. iOS App ID must belong to project 194789753908 and be ios platform
  if (!ios.appId.startsWith(
    '1:${DefaultFirebaseOptionsStaging.expectedProjectNumber}:ios:',
  )) {
    return StagingConfigurationValidation.invalid(
      'iOS appId "${ios.appId}" must match prefix "1:${DefaultFirebaseOptionsStaging.expectedProjectNumber}:ios:".',
    );
  }

  // 6. iOS bundle ID must match Staging
  if (ios.iosBundleId != 'com.example.chatApp.staging') {
    return StagingConfigurationValidation.invalid(
      'iOS bundleId "${ios.iosBundleId}" must match expected "com.example.chatApp.staging".',
    );
  }

  // 7. API keys must not be empty or placeholder
  if (android.apiKey.trim().isEmpty || android.apiKey.contains('PLACEHOLDER')) {
    return const StagingConfigurationValidation.invalid(
      'Android apiKey must be non-empty and cannot be a placeholder.',
    );
  }
  if (ios.apiKey.trim().isEmpty || ios.apiKey.contains('PLACEHOLDER')) {
    return const StagingConfigurationValidation.invalid(
      'iOS apiKey must be non-empty and cannot be a placeholder.',
    );
  }

  // 8. Storage Bucket on Android & iOS options
  if (android.storageBucket == null || android.storageBucket!.trim().isEmpty) {
    return const StagingConfigurationValidation.invalid(
      'Android storageBucket cannot be null or empty.',
    );
  }
  if (ios.storageBucket == null || ios.storageBucket!.trim().isEmpty) {
    return const StagingConfigurationValidation.invalid(
      'iOS storageBucket cannot be null or empty.',
    );
  }
  if (android.storageBucket != expectedStorageBucket) {
    return StagingConfigurationValidation.invalid(
      'Android storageBucket "${android.storageBucket}" does not match authoritative expected bucket "$expectedStorageBucket".',
    );
  }
  if (ios.storageBucket != expectedStorageBucket) {
    return StagingConfigurationValidation.invalid(
      'iOS storageBucket "${ios.storageBucket}" does not match authoritative expected bucket "$expectedStorageBucket".',
    );
  }

  // 9. Absolute Production Isolation Checks: reject all production identifiers
  if (android.projectId == 'chat-app-28ac0' ||
      ios.projectId == 'chat-app-28ac0' ||
      android.messagingSenderId == '639830188590' ||
      ios.messagingSenderId == '639830188590' ||
      android.appId.contains('639830188590') ||
      ios.appId.contains('639830188590') ||
      android.storageBucket == 'chat-app-28ac0.firebasestorage.app' ||
      android.storageBucket == 'chat-app-28ac0.appspot.com' ||
      ios.storageBucket == 'chat-app-28ac0.firebasestorage.app' ||
      ios.storageBucket == 'chat-app-28ac0.appspot.com') {
    return const StagingConfigurationValidation.invalid(
      'Production credentials detected in Staging options.',
    );
  }

  return const StagingConfigurationValidation.valid();
}

/// Staging Firebase options wrapper preserving the existing contract:
/// - [DefaultFirebaseOptionsStaging.isConfigured]
/// - [DefaultFirebaseOptionsStaging.currentPlatform]
/// - [DefaultFirebaseOptionsStaging.android]
/// - [DefaultFirebaseOptionsStaging.ios]
///
/// Ensures fail-closed execution in unconfigured mode and delegates to genuine
/// generated options only when configuration is complete and verified.
///
/// Contains NO runtime candidate-injection mechanism, setters, or test bypasses.
class DefaultFirebaseOptionsStaging {
  static const String expectedProjectId = 'study-buddy-54266';
  static const String expectedProjectNumber = '194789753908';

  /// Immutable authoritative Staging Storage Bucket.
  /// Must be sourced from authorized Firebase project configuration after IAM access is restored.
  /// Remains null until IAM permissions are provisioned, ensuring fail-closed runtime validation.
  static const String? authoritativeStorageBucket = null;

  /// Evaluates configuration validity via [validateStagingOptions].
  /// Derives options exclusively from [generated.DefaultFirebaseOptions] and [authoritativeStorageBucket].
  static StagingConfigurationValidation get validation {
    if (authoritativeStorageBucket == null) {
      return const StagingConfigurationValidation.invalid(
        'Authoritative Staging Storage Bucket is null. Staging remains unconfigured until IAM access is restored and the authoritative bucket is configured.',
      );
    }
    try {
      return validateStagingOptions(
        android: generated.DefaultFirebaseOptions.android,
        ios: generated.DefaultFirebaseOptions.ios,
        expectedStorageBucket: authoritativeStorageBucket,
      );
    } catch (e) {
      return StagingConfigurationValidation.invalid(
        'Generated options threw an error: $e',
      );
    }
  }

  /// Whether Staging options have been properly configured and validated.
  /// Derived exclusively from immutable authoritative configuration.
  static bool get isConfigured =>
      authoritativeStorageBucket != null && validation.isValid;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw const UnconfiguredStagingEnvironmentException();
    }
    return generated.DefaultFirebaseOptions.currentPlatform;
  }

  static FirebaseOptions get android {
    if (!isConfigured) {
      throw const UnconfiguredStagingEnvironmentException();
    }
    return generated.DefaultFirebaseOptions.android;
  }

  static FirebaseOptions get ios {
    if (!isConfigured) {
      throw const UnconfiguredStagingEnvironmentException();
    }
    return generated.DefaultFirebaseOptions.ios;
  }
}
