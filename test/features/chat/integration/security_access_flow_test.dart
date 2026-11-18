import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class SecurityAccessController {
  final Map<String, ConversationEntity> conversations = {};

  Either<Failure, ConversationEntity> readConversation({
    required String conversationId,
    required String? authUid,
  }) {
    if (authUid == null) {
      return const Left<Failure, ConversationEntity>(PermissionDeniedFailure());
    }

    final conv = conversations[conversationId];
    if (conv == null) {
      return const Left<Failure, ConversationEntity>(ServerFailure());
    }

    if (!conv.participantIds.contains(authUid)) {
      return const Left<Failure, ConversationEntity>(PermissionDeniedFailure());
    }

    return Right<Failure, ConversationEntity>(conv);
  }

  Either<Failure, Unit> updateGroupSettings({
    required String conversationId,
    required String? authUid,
    required String newGroupName,
  }) {
    if (authUid == null) {
      return const Left<Failure, Unit>(PermissionDeniedFailure());
    }

    final conv = conversations[conversationId];
    if (conv == null) return const Left<Failure, Unit>(ServerFailure());

    if (!conv.isGroup) {
      return const Left<Failure, Unit>(ServerFailure());
    }

    // Only admin can modify settings
    if (!conv.adminIds.contains(authUid)) {
      return const Left<Failure, Unit>(PermissionDeniedFailure());
    }

    conversations[conversationId] = conv.copyWith(groupName: newGroupName);
    return const Right<Failure, Unit>(unit);
  }

  Either<Failure, Unit> sendMessage({
    required String conversationId,
    required String? authUid,
    required String senderId,
    required String text,
  }) {
    if (authUid == null) {
      return const Left<Failure, Unit>(PermissionDeniedFailure());
    }

    // Impersonation check: authUid must match senderId
    if (authUid != senderId) {
      return const Left<Failure, Unit>(PermissionDeniedFailure());
    }

    final conv = conversations[conversationId];
    if (conv == null) return const Left<Failure, Unit>(ServerFailure());

    // Must be participant
    if (!conv.participantIds.contains(authUid)) {
      return const Left<Failure, Unit>(PermissionDeniedFailure());
    }

    // Text size check
    if (text.isEmpty || text.length > 2000) {
      return const Left<Failure, Unit>(ServerFailure());
    }

    return const Right<Failure, Unit>(unit);
  }
}

void main() {
  late SecurityAccessController security;
  const directId = 'direct_alice_bob';
  const groupId = 'group_flutter_devs';

  setUp(() {
    security = SecurityAccessController();

    final now = DateTime.now();

    // 1. Direct conversation between Alice and Bob
    security.conversations[directId] = ConversationEntity(
      id: directId,
      type: 'direct',
      participantIds: const ['alice', 'bob'],
      createdBy: 'alice',
      createdAt: now,
      updatedAt: now,
    );

    // 2. Group conversation where Alice is Admin, Bob is Member
    security.conversations[groupId] = ConversationEntity(
      id: groupId,
      type: 'group',
      groupName: 'Flutter Devs',
      participantIds: const ['alice', 'bob'],
      adminIds: const ['alice'],
      createdBy: 'alice',
      createdAt: now,
      updatedAt: now,
    );
  });

  group('Scenario C: Security Access Flow Tests', () {
    test(
      '1. Unauthenticated client: all read, write, and admin actions are rejected',
      () {
        final read = security.readConversation(
          conversationId: directId,
          authUid: null,
        );
        expect(
          read,
          equals(
            const Left<Failure, ConversationEntity>(PermissionDeniedFailure()),
          ),
        );

        final send = security.sendMessage(
          conversationId: directId,
          authUid: null,
          senderId: 'alice',
          text: 'Hello',
        );
        expect(
          send,
          equals(const Left<Failure, Unit>(PermissionDeniedFailure())),
        );

        final update = security.updateGroupSettings(
          conversationId: groupId,
          authUid: null,
          newGroupName: 'Hacked',
        );
        expect(
          update,
          equals(const Left<Failure, Unit>(PermissionDeniedFailure())),
        );
      },
    );

    test('2. Conversation participant (Alice): can read and send messages', () {
      final read = security.readConversation(
        conversationId: directId,
        authUid: 'alice',
      );
      expect(read.isRight(), isTrue);

      final send = security.sendMessage(
        conversationId: directId,
        authUid: 'alice',
        senderId: 'alice',
        text: 'Valid message from Alice',
      );
      expect(send, equals(const Right<Failure, Unit>(unit)));
    });

    test(
      '3. Non-participant (Eve): cannot read or send messages in direct or group chats',
      () {
        final readDirect = security.readConversation(
          conversationId: directId,
          authUid: 'eve',
        );
        expect(
          readDirect,
          equals(
            const Left<Failure, ConversationEntity>(PermissionDeniedFailure()),
          ),
        );

        final readGroup = security.readConversation(
          conversationId: groupId,
          authUid: 'eve',
        );
        expect(
          readGroup,
          equals(
            const Left<Failure, ConversationEntity>(PermissionDeniedFailure()),
          ),
        );

        final sendDirect = security.sendMessage(
          conversationId: directId,
          authUid: 'eve',
          senderId: 'eve',
          text: 'Attacker message',
        );
        expect(
          sendDirect,
          equals(const Left<Failure, Unit>(PermissionDeniedFailure())),
        );
      },
    );

    test(
      '4. Impersonation prevention: Alice cannot send message with senderId = Bob',
      () {
        final send = security.sendMessage(
          conversationId: directId,
          authUid: 'alice',
          senderId: 'bob', // Impersonation!
          text: 'Fake message from Bob',
        );
        expect(
          send,
          equals(const Left<Failure, Unit>(PermissionDeniedFailure())),
        );
      },
    );

    test('5. Group administrator (Alice): can update group metadata', () {
      final update = security.updateGroupSettings(
        conversationId: groupId,
        authUid: 'alice',
        newGroupName: 'Senior Flutter Architects',
      );
      expect(update, equals(const Right<Failure, Unit>(unit)));
      expect(
        security.conversations[groupId]!.groupName,
        equals('Senior Flutter Architects'),
      );
    });

    test('6. Ordinary group member (Bob): cannot update group settings', () {
      final update = security.updateGroupSettings(
        conversationId: groupId,
        authUid: 'bob',
        newGroupName: 'Bob Takeover',
      );
      expect(
        update,
        equals(const Left<Failure, Unit>(PermissionDeniedFailure())),
      );
      expect(
        security.conversations[groupId]!.groupName,
        equals('Flutter Devs'),
      );
    });
  });
}
