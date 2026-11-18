import 'dart:async';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/data/data_sources/chat_remote_data_source.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryChatBackend {
  final Map<String, UserEntity> users = {};
  final Map<String, ConversationEntity> conversations = {};
  final Map<String, List<MessageEntity>> messages = {};
  final Map<String, StreamController<List<MessageEntity>>> messageStreams = {};

  StreamController<List<MessageEntity>> getStream(String conversationId) {
    return messageStreams.putIfAbsent(
      conversationId,
      StreamController<List<MessageEntity>>.broadcast,
    );
  }

  void postMessage(MessageEntity msg) {
    final list = messages.putIfAbsent(msg.conversationId, () => [])
      ..insert(0, msg);
    getStream(msg.conversationId).add(List.from(list));

    // Update conversation preview and read state
    final conv = conversations[msg.conversationId];
    if (conv != null) {
      final updatedRead = Map<String, DateTime>.from(conv.lastReadAtByUser)
        ..[msg.senderId] = msg.createdAt;

      conversations[msg.conversationId] = conv.copyWith(
        lastMessage: msg.text,
        lastMessageAt: msg.createdAt,
        lastMessageSenderId: msg.senderId,
        lastMessageSenderName: msg.senderName,
        updatedAt: msg.createdAt,
        lastReadAtByUser: updatedRead,
      );
    }
  }

  void markRead(String conversationId, String userId) {
    final conv = conversations[conversationId];
    if (conv != null) {
      final updatedRead = Map<String, DateTime>.from(conv.lastReadAtByUser)
        ..[userId] = DateTime.now();
      conversations[conversationId] = conv.copyWith(
        lastReadAtByUser: updatedRead,
      );
    }
  }
}

class FakeIntegrationChatRepository implements ChatRepository {
  FakeIntegrationChatRepository(this.backend);
  final InMemoryChatBackend backend;

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  }) async {
    final convId = ChatRemoteDataSourceImpl.getDirectConversationId(
      currentUserId,
      otherUser.id,
    );
    final existing = backend.conversations[convId];
    if (existing != null) {
      return Right(existing);
    }

    final now = DateTime.now();
    final newConv = ConversationEntity(
      id: convId,
      type: 'direct',
      participantIds: [currentUserId, otherUser.id],
      createdBy: currentUserId,
      createdAt: now,
      updatedAt: now,
      lastReadAtByUser: {currentUserId: now},
    );
    backend.conversations[convId] = newConv;
    return Right(newConv);
  }

  @override
  Stream<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
  }) {
    return backend.getStream(conversationId).stream;
  }

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
    String? clientMessageId,
  }) async {
    final msg = MessageEntity(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
      createdAt: DateTime.now(),
    );
    backend.postMessage(msg);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    backend.markRead(conversationId, currentUserId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<UserEntity>>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    final q = query.toLowerCase();
    final results = backend.users.values
        .where((u) => u.id != currentUserId)
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
    return Right(results);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryChatBackend backend;
  late FakeIntegrationChatRepository repository;

  setUp(() {
    backend = InMemoryChatBackend();
    repository = FakeIntegrationChatRepository(backend);

    // Setup User A and User B
    backend.users['user_a'] = const UserEntity(
      id: 'user_a',
      name: 'Alice',
      email: 'alice@chat.com',
    );
    backend.users['user_b'] = const UserEntity(
      id: 'user_b',
      name: 'Bob',
      email: 'bob@chat.com',
    );
  });

  tearDown(() async {
    for (final stream in backend.messageStreams.values) {
      await stream.close();
    }
  });

  group('Scenario A: Direct Messaging Real-Time Flow', () {
    test(
      'User A discovers User B, exchanges real-time messages and updates read state',
      () async {
        // 1. User A discovers User B
        final searchResult = await repository.searchUsers(
          query: 'Bob',
          currentUserId: 'user_a',
        );
        expect(searchResult.isRight(), isTrue);
        final foundUsers = searchResult.getOrElse(() => []);
        expect(foundUsers.length, equals(1));
        expect(foundUsers.first.id, equals('user_b'));

        // 2. User A starts direct conversation with User B
        final convResult = await repository.getOrCreateDirectConversation(
          currentUserId: 'user_a',
          otherUser: foundUsers.first,
        );
        expect(convResult.isRight(), isTrue);
        final conversation = convResult.getOrElse(() => throw Exception());
        expect(conversation.id, equals('user_a_user_b'));
        expect(conversation.participantIds, containsAll(['user_a', 'user_b']));

        // 3. User B listens to messages
        final userBStream = repository.getMessages(conversation.id);
        final userBMessagesReceived = <List<MessageEntity>>[];
        final userBSub = userBStream.listen(userBMessagesReceived.add);

        // 4. User A sends a message: "Hi Bob!"
        await repository.sendMessage(
          conversationId: conversation.id,
          senderId: 'user_a',
          senderName: 'Alice',
          text: 'Hi Bob!',
        );

        // Allow stream to deliver
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(userBMessagesReceived.isNotEmpty, isTrue);
        expect(userBMessagesReceived.last.first.text, equals('Hi Bob!'));
        expect(userBMessagesReceived.last.first.senderId, equals('user_a'));

        // Verify conversation has unread state for User B
        final convAfterMsg1 = backend.conversations[conversation.id]!;
        expect(convAfterMsg1.isUnreadFor('user_b'), isTrue);
        expect(convAfterMsg1.isUnreadFor('user_a'), isFalse);

        // 5. User B marks conversation as read
        await repository.markConversationAsRead(
          conversationId: conversation.id,
          currentUserId: 'user_b',
        );
        final convAfterRead = backend.conversations[conversation.id]!;
        expect(convAfterRead.isUnreadFor('user_b'), isFalse);

        // 6. User B replies: "Hey Alice, received!"
        await repository.sendMessage(
          conversationId: conversation.id,
          senderId: 'user_b',
          senderName: 'Bob',
          text: 'Hey Alice, received!',
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          userBMessagesReceived.last.first.text,
          equals('Hey Alice, received!'),
        );
        expect(userBMessagesReceived.last.length, equals(2));

        // Verify User A now has unread state
        final convAfterReply = backend.conversations[conversation.id]!;
        expect(convAfterReply.isUnreadFor('user_a'), isTrue);
        expect(convAfterReply.isUnreadFor('user_b'), isFalse);

        await userBSub.cancel();
      },
    );
  });
}
