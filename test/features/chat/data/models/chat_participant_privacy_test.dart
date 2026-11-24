import 'package:chat_app/features/chat/data/models/chat_participant_model.dart';
import 'package:chat_app/features/chat/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatParticipantModel & Conversation Privacy Tests (Phase 4.1)', () {
    test('ChatParticipantModel.toMap() strictly excludes email field', () {
      const participant = ChatParticipantModel(
        id: 'user_alice',
        name: 'Alice Cooper',
        email: 'alice.private@example.com',
        photoUrl: 'https://example.com/avatar.jpg',
        isOnline: true,
      );

      final map = participant.toMap();

      expect(map['id'], equals('user_alice'));
      expect(map['name'], equals('Alice Cooper'));
      expect(map['photoUrl'], equals('https://example.com/avatar.jpg'));
      expect(map['isOnline'], isTrue);
      expect(map.containsKey('email'), isFalse);
    });

    test(
      'ConversationModel.toMap() direct conversation does not expose participant emails',
      () {
        final now = DateTime.now();
        final conversation = ConversationModel(
          id: 'alice_bob',
          type: 'direct',
          participantIds: const ['alice', 'bob'],
          createdBy: 'alice',
          createdAt: now,
          updatedAt: now,
          participants: const {
            'alice': ChatParticipantModel(
              id: 'alice',
              name: 'Alice',
              email: 'alice.secret@example.com',
            ),
            'bob': ChatParticipantModel(
              id: 'bob',
              name: 'Bob',
              email: 'bob.secret@example.com',
            ),
          },
        );

        final map = conversation.toMap();
        final serializedParticipants =
            map['participants'] as Map<String, dynamic>;

        expect(
          (serializedParticipants['alice'] as Map<String, dynamic>).containsKey(
            'email',
          ),
          isFalse,
        );
        expect(
          (serializedParticipants['bob'] as Map<String, dynamic>).containsKey(
            'email',
          ),
          isFalse,
        );
      },
    );

    test(
      'ConversationModel.toMap() group conversation does not expose participant emails',
      () {
        final now = DateTime.now();
        final conversation = ConversationModel(
          id: 'group_core',
          type: 'group',
          groupName: 'Core Team',
          participantIds: const ['alice', 'bob', 'charlie'],
          adminIds: const ['alice'],
          createdBy: 'alice',
          createdAt: now,
          updatedAt: now,
          participants: const {
            'alice': ChatParticipantModel(
              id: 'alice',
              name: 'Alice',
              email: 'alice@corp.com',
            ),
            'bob': ChatParticipantModel(
              id: 'bob',
              name: 'Bob',
              email: 'bob@corp.com',
            ),
            'charlie': ChatParticipantModel(
              id: 'charlie',
              name: 'Charlie',
              email: 'charlie@corp.com',
            ),
          },
        );

        final map = conversation.toMap();
        final serializedParticipants =
            map['participants'] as Map<String, dynamic>;

        expect(
          (serializedParticipants['alice'] as Map<String, dynamic>).containsKey(
            'email',
          ),
          isFalse,
        );
        expect(
          (serializedParticipants['bob'] as Map<String, dynamic>).containsKey(
            'email',
          ),
          isFalse,
        );
        expect(
          (serializedParticipants['charlie'] as Map<String, dynamic>)
              .containsKey('email'),
          isFalse,
        );
      },
    );

    test(
      'ChatParticipantModel.fromMap preserves backwards compatibility with legacy email',
      () {
        final legacyMap = {
          'name': 'Bob Legacy',
          'email': 'bob.legacy@example.com',
          'photoUrl': null,
          'isOnline': false,
        };

        final model = ChatParticipantModel.fromMap(legacyMap, 'bob');

        expect(model.id, equals('bob'));
        expect(model.name, equals('Bob Legacy'));
        expect(model.email, equals('bob.legacy@example.com'));
      },
    );
  });
}
