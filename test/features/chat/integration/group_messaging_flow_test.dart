import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGroupBackend {
  final Map<String, ConversationEntity> groups = {};
  final Map<String, List<MessageEntity>> messages = {};

  Either<Failure, ConversationEntity> updateGroupMetadata({
    required String groupId,
    required String requestingUserId,
    required String newName,
  }) {
    final group = groups[groupId];
    if (group == null) return const Left(ServerFailure());

    // Authorization check: only users in adminIds can modify metadata
    if (!group.adminIds.contains(requestingUserId)) {
      return const Left(PermissionDeniedFailure());
    }

    final updated = group.copyWith(
      groupName: newName,
      updatedAt: DateTime.now(),
    );
    groups[groupId] = updated;
    return Right(updated);
  }
}

class FakeGroupChatRepository implements ChatRepository {
  FakeGroupChatRepository(this.backend);
  final MockGroupBackend backend;

  @override
  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) async {
    final id = 'group_${DateTime.now().microsecondsSinceEpoch}';
    final participantIds = [currentUserId, ...members.map((m) => m.id)];
    final now = DateTime.now();

    final group = ConversationEntity(
      id: id,
      type: 'group',
      groupName: groupName,
      groupAvatar: groupAvatar,
      participantIds: participantIds,
      createdBy: currentUserId,
      adminIds: [currentUserId], // Creator is admin
      createdAt: now,
      updatedAt: now,
      lastReadAtByUser: {currentUserId: now},
    );

    backend.groups[id] = group;
    return Right(group);
  }

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) async {
    final group = backend.groups[conversationId];
    if (group == null || !group.participantIds.contains(senderId)) {
      return const Left(PermissionDeniedFailure());
    }

    backend.messages
        .putIfAbsent(conversationId, () => [])
        .add(
          MessageEntity(
            id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            type: type,
            createdAt: DateTime.now(),
          ),
        );
    return const Right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockGroupBackend backend;
  late FakeGroupChatRepository repository;

  setUp(() {
    backend = MockGroupBackend();
    repository = FakeGroupChatRepository(backend);
  });

  group('Scenario B: Group Messaging Flow', () {
    test(
      'User A creates group with B & C, all exchange messages, only admin modifies group',
      () async {
        // 1. User A creates group inviting B and C
        final members = [
          const UserEntity(id: 'user_b', name: 'Bob', email: 'b@chat.com'),
          const UserEntity(id: 'user_c', name: 'Charlie', email: 'c@chat.com'),
        ];

        final createResult = await repository.createGroupConversation(
          currentUserId: 'user_a',
          groupName: 'Flutter Architects',
          members: members,
        );

        expect(createResult.isRight(), isTrue);
        final group = createResult.getOrElse(() => throw Exception());
        expect(group.isGroup, isTrue);
        expect(group.participantIds.length, equals(3));
        expect(group.adminIds, contains('user_a'));
        expect(group.adminIds, isNot(contains('user_b')));

        // 2. All participants can exchange messages
        final sendA = await repository.sendMessage(
          conversationId: group.id,
          senderId: 'user_a',
          senderName: 'Alice',
          text: 'Welcome team!',
        );
        expect(sendA, equals(const Right<Failure, Unit>(unit)));

        final sendB = await repository.sendMessage(
          conversationId: group.id,
          senderId: 'user_b',
          senderName: 'Bob',
          text: 'Glad to be here!',
        );
        expect(sendB, equals(const Right<Failure, Unit>(unit)));

        final sendC = await repository.sendMessage(
          conversationId: group.id,
          senderId: 'user_c',
          senderName: 'Charlie',
          text: 'Ready to build.',
        );
        expect(sendC, equals(const Right<Failure, Unit>(unit)));

        // Non-participant (User D) cannot send message to group
        final sendD = await repository.sendMessage(
          conversationId: group.id,
          senderId: 'user_d',
          senderName: 'Attacker',
          text: 'Spam',
        );
        expect(
          sendD,
          equals(const Left<Failure, Unit>(PermissionDeniedFailure())),
        );

        // 3. Unauthorized participant (Bob) cannot modify group settings
        final unauthorizedUpdate = backend.updateGroupMetadata(
          groupId: group.id,
          requestingUserId: 'user_b',
          newName: 'Hacked Group Name',
        );
        expect(
          unauthorizedUpdate,
          equals(
            const Left<Failure, ConversationEntity>(PermissionDeniedFailure()),
          ),
        );

        // 4. Authorized administrator (Alice) can update group metadata
        final authorizedUpdate = backend.updateGroupMetadata(
          groupId: group.id,
          requestingUserId: 'user_a',
          newName: 'Flutter Core Engineering',
        );
        expect(authorizedUpdate.isRight(), isTrue);
        expect(
          backend.groups[group.id]!.groupName,
          equals('Flutter Core Engineering'),
        );
      },
    );
  });
}
