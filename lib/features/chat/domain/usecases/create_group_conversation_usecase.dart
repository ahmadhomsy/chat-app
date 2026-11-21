import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

class CreateGroupConversationUseCase {
  CreateGroupConversationUseCase(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, ConversationEntity>> call({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) {
    return repository.createGroupConversation(
      currentUserId: currentUserId,
      groupName: groupName,
      members: members,
      groupAvatar: groupAvatar,
    );
  }
}
