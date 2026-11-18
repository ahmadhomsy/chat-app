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

/// Simulated Multi-Device RTDB Connection Registry
class MultiDeviceRegistry {
  final Map<String, Set<String>> _activeUserConnections = {};
  final List<Map<String, dynamic>> presenceHistory = [];

  void connect({required String uid, required String deviceId}) {
    _activeUserConnections.putIfAbsent(uid, () => <String>{}).add(deviceId);
    _syncPresence(uid);
  }

  void disconnect({required String uid, required String deviceId}) {
    _activeUserConnections[uid]?.remove(deviceId);
    _syncPresence(uid);
  }

  bool isUserOnline(String uid) {
    return _activeUserConnections[uid]?.isNotEmpty ?? false;
  }

  int activeConnectionCount(String uid) {
    return _activeUserConnections[uid]?.length ?? 0;
  }

  void _syncPresence(String uid) {
    final online = isUserOnline(uid);
    presenceHistory.add({'uid': uid, 'isOnline': online});
  }
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

  group('PresenceService Baseline Tests', () {
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
      'presence operation handles unauthenticated user gracefully without throwing',
      () async {
        fakeAuth.mockUser = null; // Unauthenticated
        await presenceService.setFirestorePresence(isOnline: true);
        expect(recordedPresenceUpdates.isEmpty, isTrue);
      },
    );
  });

  group('Multi-Device Presence Architecture Tests', () {
    late MultiDeviceRegistry registry;
    const userId = 'user_multi_123';

    setUp(() {
      registry = MultiDeviceRegistry();
    });

    test('simultaneous connections from multiple devices', () {
      // Device A (Phone) connects
      registry.connect(uid: userId, deviceId: 'phone_01');
      expect(registry.isUserOnline(userId), isTrue);
      expect(registry.activeConnectionCount(userId), equals(1));

      // Device B (Tablet) connects simultaneously
      registry.connect(uid: userId, deviceId: 'tablet_01');
      expect(registry.isUserOnline(userId), isTrue);
      expect(registry.activeConnectionCount(userId), equals(2));

      // Both devices are tracked uniquely
      expect(registry.presenceHistory.last['isOnline'], isTrue);
    });

    test(
      'partial disconnect: user remains online while one device is active',
      () {
        registry
          ..connect(uid: userId, deviceId: 'phone_01')
          ..connect(uid: userId, deviceId: 'tablet_01');
        expect(registry.isUserOnline(userId), isTrue);

        // Phone disconnects (backgrounded or lost connection)
        registry.disconnect(uid: userId, deviceId: 'phone_01');

        // User MUST still be online because tablet is active
        expect(registry.isUserOnline(userId), isTrue);
        expect(registry.activeConnectionCount(userId), equals(1));
        expect(registry.presenceHistory.last['isOnline'], isTrue);
      },
    );

    test(
      'full disconnect: user becomes offline only when final device disconnects',
      () {
        registry
          ..connect(uid: userId, deviceId: 'phone_01')
          ..connect(uid: userId, deviceId: 'tablet_01');
        expect(registry.isUserOnline(userId), isTrue);

        // First device disconnects
        registry.disconnect(uid: userId, deviceId: 'phone_01');
        expect(registry.isUserOnline(userId), isTrue);

        // Final device disconnects
        registry.disconnect(uid: userId, deviceId: 'tablet_01');

        // Now and only now should user be marked offline
        expect(registry.isUserOnline(userId), isFalse);
        expect(registry.activeConnectionCount(userId), equals(0));
        expect(registry.presenceHistory.last['isOnline'], isFalse);
      },
    );

    test(
      'reconnection: reconnected device uses stable ID without duplicating connections',
      () {
        // Connect phone
        registry.connect(uid: userId, deviceId: 'phone_01');
        expect(registry.activeConnectionCount(userId), equals(1));

        // Disconnect phone
        registry.disconnect(uid: userId, deviceId: 'phone_01');
        expect(registry.isUserOnline(userId), isFalse);

        // Reconnect phone with the same device ID
        registry.connect(uid: userId, deviceId: 'phone_01');
        expect(registry.isUserOnline(userId), isTrue);
        // Ensure no duplicate connection entry was created for same deviceId
        expect(registry.activeConnectionCount(userId), equals(1));
      },
    );
  });
}
