import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:equatable/equatable.dart';

abstract class ConversationsState extends Equatable {
  const ConversationsState();

  @override
  List<Object?> get props => [];
}

class ConversationsInitial extends ConversationsState {}

class ConversationsLoading extends ConversationsState {}

class ConversationsLoaded extends ConversationsState {
  const ConversationsLoaded(this.conversations);

  final List<ConversationEntity> conversations;

  @override
  List<Object?> get props => [conversations];
}

class ConversationsEmpty extends ConversationsState {}

class ConversationsError extends ConversationsState {
  const ConversationsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
