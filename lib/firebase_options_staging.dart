// Wrapper for ChatUp Staging Environment Firebase Options.
// Target Firebase Project: study-buddy-54266 (Project Number: 194789753908)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:meta/meta.dart';
import 'firebase_options_staging.generated.dart' as generated;

/// Exception thrown when the Staging environment is executed prior to real
/// Firebase App registration in study-buddy-54266.
class UnconfiguredStagingEnvironmentException implements Exception {
  final String message;
  const UnconfiguredStagingEnvironmentException([
    this.message =
        'ChatUp Staging environment is pending live Firebase App registration in project study-buddy-54266 (Project Number: 194789753908). '
        'Real Firebase configuration options must be generated via FlutterFire CLI once the authorized IAM account completes app registration.',
  ]);

  @override
  String toString() => 'UnconfiguredStagingEnvironmentException: $message';
}

/// Staging Firebase options wrapper preserving the existing contract:
/// - [DefaultFirebaseOptionsStaging.isConfigured]
/// - [DefaultFirebaseOptionsStaging.currentPlatform]
/// - [DefaultFirebaseOptionsStaging.android]
/// - [DefaultFirebaseOptionsStaging.ios]
///
/// Ensures fail-closed execution in unconfigured mode and delegates to genuine
/// generated options only when configuration is complete and verified.
class DefaultFirebaseOptionsStaging {
  static const String expectedProjectId = 'study-buddy-54266';
  static const String expectedProjectNumber = '194789753908';

  // Test / runtime injection hooks
  static FirebaseOptions? _overrideCurrentPlatform;
  static FirebaseOptions? _overrideAndroid;
  static FirebaseOptions? _overrideIos;
  static bool? _overrideIsConfigured;

  /// Internal / test setter to inject genuine or mock options
  @visibleForTesting
  static void setMockConfiguredOptions({
    FirebaseOptions? currentPlatform,
    FirebaseOptions? android,
    FirebaseOptions? ios,
  }) {
    _overrideCurrentPlatform = currentPlatform;
    _overrideAndroid = android;
    _overrideIos = ios;
    _overrideIsConfigured = true;
  }

  /// Reset to unconfigured state
  @visibleForTesting
  static void resetToUnconfigured() {
    _overrideCurrentPlatform = null;
    _overrideAndroid = null;
    _overrideIos = null;
    _overrideIsConfigured = null;
  }

  /// Whether Staging options have been properly configured and validated.
  /// Never marks configured merely because the generated file exists.
  static bool get isConfigured {
    if (_overrideIsConfigured != null) {
      return _overrideIsConfigured!;
    }
    return _validateGeneratedOptions();
  }

  static bool _validateGeneratedOptions() {
    try {
      final androidOptions = generated.DefaultFirebaseOptions.android;
      final iosOptions = generated.DefaultFirebaseOptions.ios;

      // Project ID validation: must strictly match study-buddy-54266
      if (androidOptions.projectId != expectedProjectId ||
          iosOptions.projectId != expectedProjectId) {
        return false;
      }

      // Sender ID validation: must strictly match 194789753908
      if (androidOptions.messagingSenderId != expectedProjectNumber ||
          iosOptions.messagingSenderId != expectedProjectNumber) {
        return false;
      }

      // Android App ID must belong to project 194789753908 and be android
      if (!androidOptions.appId.startsWith(
        '1:$expectedProjectNumber:android:',
      )) {
        return false;
      }

      // iOS App ID must belong to project 194789753908 and be ios
      if (!iosOptions.appId.startsWith('1:$expectedProjectNumber:ios:')) {
        return false;
      }

      // iOS bundle ID must match Staging
      if (iosOptions.iosBundleId != 'com.example.chatApp.staging') {
        return false;
      }

      // Must not contain placeholder or empty values
      if (androidOptions.apiKey.isEmpty ||
          androidOptions.apiKey.contains('PLACEHOLDER') ||
          iosOptions.apiKey.isEmpty ||
          iosOptions.apiKey.contains('PLACEHOLDER')) {
        return false;
      }

      // Never match Production
      if (androidOptions.projectId == 'chat-app-28ac0' ||
          androidOptions.messagingSenderId == '639830188590' ||
          androidOptions.appId.contains('639830188590')) {
        return false;
      }

      return true;
    } catch (_) {
      // If generated file throws (e.g. unconfigured stub), it is not configured
      return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw const UnconfiguredStagingEnvironmentException();
    }
    if (_overrideCurrentPlatform != null) {
      return _overrideCurrentPlatform!;
    }
    return generated.DefaultFirebaseOptions.currentPlatform;
  }

  static FirebaseOptions get android {
    if (!isConfigured) {
      throw const UnconfiguredStagingEnvironmentException();
    }
    if (_overrideAndroid != null) {
      return _overrideAndroid!;
    }
    return generated.DefaultFirebaseOptions.android;
  }

  static FirebaseOptions get ios {
    if (!isConfigured) {
      throw const UnconfiguredStagingEnvironmentException();
    }
    if (_overrideIos != null) {
      return _overrideIos!;
    }
    return generated.DefaultFirebaseOptions.ios;
  }
}
