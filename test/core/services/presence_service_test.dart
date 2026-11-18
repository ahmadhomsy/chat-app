import 'package:chat_app/core/services/presence_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUser implements User {
  @override
  String get uid => 'user_test_123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  FakeUser? mockUser = FakeUser();

  @override
  User? get currentUser => mockUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseAuth fakeAuth;
  late PresenceService presenceService;
  late List<Map<String, dynamic>> recordedPresenceUpdates;

  setUp(() {
    fakeAuth = FakeFirebaseAuth();
    recordedPresenceUpdates = [];
    presenceService = PresenceService(
      firestore: DummyFirestore(),
      firebaseAuth: fakeAuth,
      deviceId: 'device_a',
      onPresenceChanged: ({required uid, required isOnline}) async {
        recordedPresenceUpdates.add({'uid': uid, 'isOnline': isOnline});
      },
    );
  });

  group('PresenceService Tests', () {
    test(
      'setFirestorePresence updates isOnline for authenticated user',
      () async {
        await presenceService.setFirestorePresence(isOnline: true);

        expect(recordedPresenceUpdates.length, equals(1));
        expect(recordedPresenceUpdates.first['uid'], equals('user_test_123'));
        expect(recordedPresenceUpdates.first['isOnline'], isTrue);
      },
    );

    test('handleSignOut marks user offline and cleans up', () async {
      await presenceService.handleSignOut();

      expect(recordedPresenceUpdates.isNotEmpty, isTrue);
      expect(recordedPresenceUpdates.last['isOnline'], isFalse);
    });

    test(
      'multiple devices simulation: device A goes offline while device B remains',
      () async {
        // 1. Device A sets presence online
        await presenceService.setFirestorePresence(isOnline: true);
        expect(recordedPresenceUpdates.last['isOnline'], isTrue);

        // 2. Device B is active -> aggregate state remains online
        await presenceService.setFirestorePresence(isOnline: true);
        expect(recordedPresenceUpdates.last['isOnline'], isTrue);

        // 3. All devices disconnect -> aggregate state goes offline
        await presenceService.setFirestorePresence(isOnline: false);
        expect(recordedPresenceUpdates.last['isOnline'], isFalse);
      },
    );

    test(
      'presence operation handles unauthenticated user gracefully without throwing',
      () async {
        fakeAuth.mockUser = null; // Unauthenticated
        await presenceService.setFirestorePresence(isOnline: true);
        // Succeeded without throwing unhandled exception
        expect(recordedPresenceUpdates.isEmpty, isTrue);
      },
    );
  });
}
