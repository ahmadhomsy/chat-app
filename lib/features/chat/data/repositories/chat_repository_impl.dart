import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/data/data_sources/chat_remote_data_source.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  final ChatRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  Future<Either<Failure, T>> _execute<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return const Left(OfflineFailure());
    }

    try {
      final result = await action();
      return Right(result);
    } on PermissionDeniedException {
      return const Left(PermissionDeniedFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on OfflineException {
      return const Left(OfflineFailure());
    } on Object catch (_) {
      return const Left(UnExpectedFailure());
    }
  }

  @override
  Stream<List<ConversationEntity>> getConversations(
    String currentUserId, {
    String? type,
  }) {
    return remoteDataSource.getConversationsStream(currentUserId, type: type);
  }

  @override
  Stream<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
  }) {
    return remoteDataSource.getMessagesStream(conversationId, limit: limit);
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  }) {
    return _execute(
      () => remoteDataSource.loadOlderMessages(
        conversationId,
        beforeDate: beforeDate,
        limit: limit,
      ),
    );
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  }) {
    return _execute(
      () => remoteDataSource.getOrCreateDirectConversation(
        currentUserId: currentUserId,
        otherUser: otherUser,
      ),
    );
  }

  @override
  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) {
    return _execute(
      () => remoteDataSource.createGroupConversation(
        currentUserId: currentUserId,
        groupName: groupName,
        members: members,
        groupAvatar: groupAvatar,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) {
    return _execute(
      () => remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        text: text,
        type: type,
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) {
    return _execute(
      () => remoteDataSource.markConversationAsRead(
        conversationId: conversationId,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Future<Either<Failure, List<UserEntity>>> searchUsers({
    required String query,
    required String currentUserId,
  }) {
    return _execute(
      () => remoteDataSource.searchUsers(
        query: query,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  }) {
    return _execute(
      () => remoteDataSource.getAllUsers(
        currentUserId: currentUserId,
        limit: limit,
      ),
    );
  }
}
