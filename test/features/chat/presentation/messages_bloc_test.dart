import 'dart:async';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/mark_as_read_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_bloc.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMessagesChatRepository implements ChatRepository {
  StreamController<List<MessageEntity>> messagesController =
      StreamController<List<MessageEntity>>.broadcast();
  bool markAsReadCalled = false;
  bool sendMessageCalled = false;
  bool loadOlderCalled = false;

  @override
  Stream<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
  }) {
    return messagesController.stream;
  }

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    markAsReadCalled = true;
    return const Right(unit);
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
    sendMessageCalled = true;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  }) async {
    loadOlderCalled = true;
    return const Right([]);
  }

  @override
  Stream<List<ConversationEntity>> getConversations(
    String currentUserId, {
    String? type,
  }) => const Stream.empty();

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserEntity>>> searchUsers({
    required String query,
    required String currentUserId,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  }) => throw UnimplementedError();
}

void main() {
  late MessagesBloc bloc;
  late FakeMessagesChatRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeMessagesChatRepository();
    bloc = MessagesBloc(
      getMessagesUseCase: GetMessagesUseCase(fakeRepo),
      sendMessageUseCase: SendMessageUseCase(fakeRepo),
      markAsReadUseCase: MarkAsReadUseCase(fakeRepo),
      chatRepository: fakeRepo,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  group('MessagesBloc Tests', () {
    test('initial state is MessagesInitial', () {
      expect(bloc.state, equals(MessagesInitial()));
    });

    test('MessagesUpdatedEvent emits MessagesLoaded with messages', () async {
      final msg = MessageEntity(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'u1',
        text: 'Hello!',
        createdAt: DateTime.now(),
      );

      final expected = [
        MessagesLoaded(messages: [msg], hasReachedEnd: true),
      ];

      final expectation = expectLater(bloc.stream, emitsInOrder(expected));

      bloc.add(MessagesUpdatedEvent([msg]));

      await expectation;
    });

    test(
      'MessagesUpdatedEvent emits MessagesEmpty when list is empty',
      () async {
        final expected = [
          MessagesEmpty(),
        ];

        final expectation = expectLater(bloc.stream, emitsInOrder(expected));

        bloc.add(const MessagesUpdatedEvent([]));

        await expectation;
      },
    );

    test('SendMessageEvent invokes sendMessageUseCase', () async {
      bloc.add(
        SendMessageEvent(
          conversationId: 'c1',
          senderId: 'u1',
          senderName: 'User 1',
          text: 'A new message',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeRepo.sendMessageCalled, isTrue);
    });

    test('MarkAsReadEvent invokes markAsReadUseCase', () async {
      bloc.add(
        const MarkAsReadEvent(
          conversationId: 'c1',
          currentUserId: 'u1',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeRepo.markAsReadCalled, isTrue);
    });
  });
}
