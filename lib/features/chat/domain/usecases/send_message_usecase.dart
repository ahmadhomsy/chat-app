import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

class SendMessageUseCase {
  SendMessageUseCase(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, Unit>> call({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) {
    return repository.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
    );
  }
}
