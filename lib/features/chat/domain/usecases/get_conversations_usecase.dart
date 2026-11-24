import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';

class GetConversationsUseCase {
  GetConversationsUseCase(this.repository);

  final ChatRepository repository;

  Stream<List<ConversationEntity>> call(String currentUserId, {String? type}) {
    return repository.getConversations(currentUserId, type: type);
  }
}
