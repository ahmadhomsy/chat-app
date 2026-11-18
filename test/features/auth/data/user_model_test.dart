import 'package:chat_app/features/auth/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel Test', () {
    test('should parse correctly from Map with Timestamp', () {
      final now = DateTime.now();
      final map = {
        'name': 'Ahmad Homsy',
        'email': 'ahmad@example.com',
        'photoUrl': 'https://example.com/photo.png',
        'isOnline': true,
        'createdAt': Timestamp.fromDate(now),
        'lastSeen': Timestamp.fromDate(now),
        'provider': 'email',
      };

      final model = UserModel.fromMap(map, 'user_123');

      expect(model.id, 'user_123');
      expect(model.name, 'Ahmad Homsy');
      expect(model.username, 'Ahmad Homsy'); // Backwards compatibility
      expect(model.email, 'ahmad@example.com');
      expect(model.photoUrl, 'https://example.com/photo.png');
      expect(model.isOnline, true);
      expect(model.provider, 'email');
      expect(
        model.createdAt?.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('should handle null timestamps gracefully without throwing', () {
      final map = {
        'name': 'Test User',
        'email': 'test@example.com',
        'photoUrl': null,
        'createdAt': null,
        'lastSeen': null,
      };

      final model = UserModel.fromMap(map, 'user_456');

      expect(model.id, 'user_456');
      expect(model.createdAt, isNull);
      expect(model.lastSeen, isNull);
      expect(model.isOnline, false);
    });

    test('should convert to Map correctly', () {
      final now = DateTime.now();
      final model = UserModel(
        id: 'user_789',
        name: 'Jane Doe',
        email: 'jane@example.com',
        photoUrl: 'https://example.com/jane.jpg',
        createdAt: now,
      );

      final map = model.toMap();

      expect(map['name'], 'Jane Doe');
      expect(map['email'], 'jane@example.com');
      expect(map['photoUrl'], 'https://example.com/jane.jpg');
      expect(map['isOnline'], false);
      expect(map['createdAt'], isA<Timestamp>());
    });
  });
}
