import 'dart:async';
import 'package:chat_app/core/services/notification_service.dart';
import 'package:chat_app/core/services/presence_service.dart';
import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/firebase_options_development.dart';
import 'package:chat_app/injection_container.dart' as di;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';

class Bootstrap {
  static const String productionProjectId = 'chat-app-28ac0';
  static const String stagingProjectId = 'study-buddy-54266';
  static const String demoProjectId = 'demo-chatup';

  /// Validates that emulator and cloud environments are strictly segregated.
  /// Rejects production and staging options when useEmulators is true.
  /// Rejects demo options when useEmulators is false.
  static void validateConfiguration({
    required FirebaseOptions options,
    required bool useEmulators,
  }) {
    if (useEmulators) {
      if (options.projectId == productionProjectId ||
          options.projectId == stagingProjectId) {
        throw StateError(
          'FATAL: Local emulators cannot be configured with ${options.projectId} options. '
          'Development emulator environment must target demo project ($demoProjectId) to prevent accidental cloud resource access or billing.',
        );
      }
    } else {
      if (options.projectId == demoProjectId) {
        throw StateError(
          'FATAL: Demo project ($demoProjectId) can only be executed with useEmulators: true.',
        );
      }
    }
  }

  static Future<void> init({
    FirebaseOptions? firebaseOptions,
    bool useEmulators = false,
  }) async {
    final options =
        firebaseOptions ??
        (useEmulators
            ? DefaultFirebaseOptionsDevelopment.currentPlatform
            : DefaultFirebaseOptions.currentPlatform);

    validateConfiguration(options: options, useEmulators: useEmulators);

    await ScreenUtil.ensureScreenSize();
    await Firebase.initializeApp(
      options: options,
    );

    if (useEmulators) {
      await _configureEmulators();
    }

    await GetStorage.init();
    await di.init();

    // Initialize presence and notification services
    di.sl<PresenceService>().initialize();

    // In development/emulator mode, isolate external push notification integrations
    if (!useEmulators) {
      unawaited(di.sl<NotificationService>().initialize());
    } else {
      debugPrint(
        '[Bootstrap] Push notifications disabled in development emulator mode.',
      );
    }
  }

  static Future<void> _configureEmulators() async {
    final host = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
        ? '10.0.2.2'
        : 'localhost';

    try {
      debugPrint(
        '[Bootstrap] Connecting to local Firebase Emulators at $host...',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      debugPrint(
        '[Bootstrap] Successfully bound all Firebase clients to local Emulators.',
      );
    } catch (e, stack) {
      debugPrint(
        '[Bootstrap] FATAL: Failed to configure Firebase Emulators: $e\n$stack',
      );
      throw StateError(
        'FATAL: Development environment failed to bind to local Firebase Emulators: $e. '
        'Failing closed to prevent connecting to Production.',
      );
    }
  }
}
