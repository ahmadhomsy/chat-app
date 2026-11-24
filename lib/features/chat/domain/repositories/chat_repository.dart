import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:dartz/dartz.dart';

abstract class ChatRepository {
  Stream<List<ConversationEntity>> getConversations(
    String currentUserId, {
    String? type,
  });

  Stream<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
  });

  Future<Either<Failure, List<MessageEntity>>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  });

  Future<Either<Failure, ConversationEntity>> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  });

  Future<Either<Failure, ConversationEntity>> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  });

  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
    String? clientMessageId,
  });

  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  });

  Future<Either<Failure, List<UserEntity>>> searchUsers({
    required String query,
    required String currentUserId,
  });

  Future<Either<Failure, List<UserEntity>>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  });
}
