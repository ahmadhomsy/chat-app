import 'package:chat_app/core/bootstrap/bootstrap.dart';
import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/firebase_options_development.dart';
import 'package:chat_app/firebase_options_staging.dart';
import 'package:firebase_core/firebase_core.dart';
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

    test(
      'Development FirebaseOptions targets demo-chatup exclusively on all platforms',
      () {
        expect(
          DefaultFirebaseOptionsDevelopment.demoProjectId,
          'demo-chatup',
        );
        expect(
          DefaultFirebaseOptionsDevelopment.android.projectId,
          'demo-chatup',
        );
        expect(
          DefaultFirebaseOptionsDevelopment.android.messagingSenderId,
          '100000000000',
        );
        expect(
          DefaultFirebaseOptionsDevelopment.android.storageBucket,
          'demo-chatup.appspot.com',
        );

        expect(
          DefaultFirebaseOptionsDevelopment.ios.projectId,
          'demo-chatup',
        );
        expect(
          DefaultFirebaseOptionsDevelopment.ios.messagingSenderId,
          '100000000000',
        );
        expect(
          DefaultFirebaseOptionsDevelopment.ios.iosBundleId,
          'com.example.chatApp.dev',
        );

        expect(
          DefaultFirebaseOptionsDevelopment.web.projectId,
          'demo-chatup',
        );
        expect(
          DefaultFirebaseOptionsDevelopment.web.authDomain,
          'demo-chatup.firebaseapp.com',
        );
      },
    );

    test(
      'Development options never match Production or Staging project identities',
      () {
        const devId = DefaultFirebaseOptionsDevelopment.demoProjectId;
        expect(devId, isNot(equals(DefaultFirebaseOptions.android.projectId)));
        expect(
          devId,
          isNot(equals(DefaultFirebaseOptionsStaging.expectedProjectId)),
        );

        const devSender = DefaultFirebaseOptionsDevelopment.demoProjectNumber;
        expect(
          devSender,
          isNot(equals(DefaultFirebaseOptions.android.messagingSenderId)),
        );
        expect(
          devSender,
          isNot(equals(DefaultFirebaseOptionsStaging.expectedProjectNumber)),
        );
      },
    );

    test(
      'Bootstrap.validateConfiguration rejects Production and Staging options when useEmulators is true',
      () {
        // Production Android
        expect(
          () => Bootstrap.validateConfiguration(
            options: DefaultFirebaseOptions.android,
            useEmulators: true,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Local emulators cannot be configured with chat-app-28ac0 options',
              ),
            ),
          ),
        );

        // Production iOS
        expect(
          () => Bootstrap.validateConfiguration(
            options: DefaultFirebaseOptions.ios,
            useEmulators: true,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Local emulators cannot be configured with chat-app-28ac0 options',
              ),
            ),
          ),
        );

        // Staging options
        const stagingMockOptions = FirebaseOptions(
          apiKey: 'mock-staging-key',
          appId: '1:194789753908:android:dummy',
          messagingSenderId: '194789753908',
          projectId: 'study-buddy-54266',
        );
        expect(
          () => Bootstrap.validateConfiguration(
            options: stagingMockOptions,
            useEmulators: true,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Local emulators cannot be configured with study-buddy-54266 options',
              ),
            ),
          ),
        );
      },
    );

    test(
      'Bootstrap.validateConfiguration rejects demo options when useEmulators is false',
      () {
        expect(
          () => Bootstrap.validateConfiguration(
            options: DefaultFirebaseOptionsDevelopment.android,
            useEmulators: false,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(
                'Demo project (demo-chatup) can only be executed with useEmulators: true',
              ),
            ),
          ),
        );
      },
    );

    test(
      'Bootstrap.validateConfiguration succeeds for valid isolated configurations',
      () {
        // Development demo options with emulators = true
        expect(
          () => Bootstrap.validateConfiguration(
            options: DefaultFirebaseOptionsDevelopment.android,
            useEmulators: true,
          ),
          returnsNormally,
        );

        expect(
          () => Bootstrap.validateConfiguration(
            options: DefaultFirebaseOptionsDevelopment.ios,
            useEmulators: true,
          ),
          returnsNormally,
        );

        // Production options with emulators = false
        expect(
          () => Bootstrap.validateConfiguration(
            options: DefaultFirebaseOptions.android,
            useEmulators: false,
          ),
          returnsNormally,
        );
      },
    );
  });
}
