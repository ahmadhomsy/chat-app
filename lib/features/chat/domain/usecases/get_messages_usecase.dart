import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';

class GetMessagesUseCase {
  GetMessagesUseCase(this.repository);

  final ChatRepository repository;

  Stream<List<MessageEntity>> call(String conversationId, {int limit = 30}) {
    return repository.getMessages(conversationId, limit: limit);
  }
}
