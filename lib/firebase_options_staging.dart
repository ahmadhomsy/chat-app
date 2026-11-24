// Template for ChatUp Staging Environment.
// Target Firebase Project: study-buddy-54266 (Project Number: 194789753908)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

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

/// Default [FirebaseOptions] for ChatUp Staging environment (`study-buddy-54266`).
///
/// NOTE: This file is an unconfigured template pending live Firebase App
/// registration in project `study-buddy-54266` (Project Number: `194789753908`).
/// Attempting to access these options before live registration completes will throw
/// [UnconfiguredStagingEnvironmentException] to fail closed and prevent connecting
/// to production or using fabricated credentials.
class DefaultFirebaseOptionsStaging {
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform {
    throw const UnconfiguredStagingEnvironmentException();
  }

  static FirebaseOptions get android {
    throw const UnconfiguredStagingEnvironmentException();
  }

  static FirebaseOptions get ios {
    throw const UnconfiguredStagingEnvironmentException();
  }
}
