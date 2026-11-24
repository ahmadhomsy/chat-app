import 'package:chat_app/firebase_options_staging.generated.dart' as generated;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Deterministic Staging FirebaseOptions Identity & Production Isolation Verification',
    () {
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

      // 6. Absolute Production Isolation Check: verify no production project ID or App ID references exist
      expect(android.projectId, isNot(equals('chat-app-28ac0')));
      expect(ios.projectId, isNot(equals('chat-app-28ac0')));
      expect(android.messagingSenderId, isNot(equals('639830188590')));
      expect(ios.messagingSenderId, isNot(equals('639830188590')));
      expect(android.appId, isNot(contains('639830188590')));
      expect(ios.appId, isNot(contains('639830188590')));

      // 7. Non-empty, non-placeholder API keys
      expect(android.apiKey.isNotEmpty, isTrue);
      expect(android.apiKey, isNot(contains('PLACEHOLDER')));
      expect(ios.apiKey.isNotEmpty, isTrue);
      expect(ios.apiKey, isNot(contains('PLACEHOLDER')));
    },
  );
}
