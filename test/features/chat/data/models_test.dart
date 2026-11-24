import 'package:chat_app/features/chat/data/data_sources/chat_remote_data_source.dart';
import 'package:chat_app/features/chat/data/models/conversation_model.dart';
import 'package:chat_app/features/chat/data/models/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Models & Deterministic ID Tests', () {
    test(
      'getDirectConversationId produces deterministic ID regardless of order',
      () {
        const uid1 = 'alice_uid';
        const uid2 = 'bob_uid';

        final id1 = ChatRemoteDataSourceImpl.getDirectConversationId(
          uid1,
          uid2,
        );
        final id2 = ChatRemoteDataSourceImpl.getDirectConversationId(
          uid2,
          uid1,
        );

        expect(id1, equals('alice_uid_bob_uid'));
        expect(id2, equals('alice_uid_bob_uid'));
        expect(id1, equals(id2));
      },
    );

    test(
      'ConversationModel correctly parses from Map and detects unread status',
      () {
        final now = DateTime.now();
        final map = {
          'type': 'direct',
          'participantIds': ['user1', 'user2'],
          'participants': {
            'user1': {'name': 'User One', 'photoUrl': null, 'isOnline': true},
            'user2': {'name': 'User Two', 'photoUrl': null, 'isOnline': false},
          },
          'createdBy': 'user1',
          'createdAt': Timestamp.fromDate(now),
          'lastMessage': 'Hello there!',
          'lastMessageAt': Timestamp.fromDate(now),
          'lastMessageSenderId': 'user2',
          'lastReadAtByUser': {
            'user1': Timestamp.fromDate(
              now.subtract(const Duration(minutes: 5)),
            ),
            'user2': Timestamp.fromDate(now),
          },
        };

        final conversation = ConversationModel.fromMap(map, 'conv_123');

        expect(conversation.id, 'conv_123');
        expect(conversation.type, 'direct');
        expect(conversation.isGroup, false);
        expect(conversation.getDisplayName('user1'), 'User Two');
        expect(conversation.getDisplayName('user2'), 'User One');
        expect(conversation.hasUnreadMessages('user1'), true);
        expect(conversation.hasUnreadMessages('user2'), false);
      },
    );

    test('MessageModel parses from Map and identifies sender', () {
      final now = DateTime.now();
      final map = {
        'senderId': 'user1',
        'senderName': 'Alice',
        'text': 'How are you?',
        'type': 'text',
        'createdAt': Timestamp.fromDate(now),
      };

      final message = MessageModel.fromMap(map, 'msg_001', 'conv_123');

      expect(message.id, 'msg_001');
      expect(message.conversationId, 'conv_123');
      expect(message.text, 'How are you?');
      expect(message.isMine('user1'), true);
      expect(message.isMine('user2'), false);
    });
  });
}
