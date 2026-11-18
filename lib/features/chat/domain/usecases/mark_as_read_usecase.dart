import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

class MarkAsReadUseCase {
  MarkAsReadUseCase(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, Unit>> call({
    required String conversationId,
    required String currentUserId,
  }) {
    return repository.markConversationAsRead(
      conversationId: conversationId,
      currentUserId: currentUserId,
    );
  }
}
