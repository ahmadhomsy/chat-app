import 'dart:async';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeChatRepository implements ChatRepository {
  StreamController<List<ConversationEntity>> controller =
      StreamController<List<ConversationEntity>>.broadcast();

  @override
  Stream<List<ConversationEntity>> getConversations(
    String currentUserId, {
    String? type,
  }) {
    return controller.stream;
  }

  @override
  Stream<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
  }) {
    return const Stream.empty();
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  }) async => const Right([]);

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, List<UserEntity>>> searchUsers({
    required String query,
    required String currentUserId,
  }) async => const Right([]);

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  }) async => const Right([]);
}

void main() {
  late ConversationsCubit cubit;
  late FakeChatRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeChatRepository();
    cubit = ConversationsCubit(
      getConversationsUseCase: GetConversationsUseCase(fakeRepo),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  group('ConversationsCubit Tests', () {
    test('initial state is ConversationsInitial', () {
      expect(cubit.state, equals(ConversationsInitial()));
    });

    test(
      'emits [ConversationsLoading, ConversationsEmpty] when stream emits empty list',
      () async {
        final expected = [
          ConversationsLoading(),
          ConversationsEmpty(),
        ];

        final expectation = expectLater(cubit.stream, emitsInOrder(expected));

        cubit.loadConversations('user_1');
        fakeRepo.controller.add([]);

        await expectation;
      },
    );

    test(
      'emits [ConversationsLoading, ConversationsLoaded] when stream emits conversations',
      () async {
        final conv = ConversationEntity(
          id: 'c1',
          type: 'direct',
          participantIds: const ['user_1', 'user_2'],
          createdBy: 'user_1',
          createdAt: DateTime.now(),
        );

        final expected = [
          ConversationsLoading(),
          ConversationsLoaded([conv]),
        ];

        final expectation = expectLater(cubit.stream, emitsInOrder(expected));

        cubit.loadConversations('user_1');
        fakeRepo.controller.add([conv]);

        await expectation;
      },
    );
  });
}
