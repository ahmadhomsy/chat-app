import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

class StartDirectConversationUseCase {
  StartDirectConversationUseCase(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, ConversationEntity>> call({
    required String currentUserId,
    required UserEntity otherUser,
  }) {
    return repository.getOrCreateDirectConversation(
      currentUserId: currentUserId,
      otherUser: otherUser,
    );
  }
}
