import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:equatable/equatable.dart';

abstract class MessagesEvent extends Equatable {
  const MessagesEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessagesEvent extends MessagesEvent {
  const LoadMessagesEvent({
    required this.conversationId,
    required this.currentUserId,
    this.limit = 30,
  });

  final String conversationId;
  final String currentUserId;
  final int limit;

  @override
  List<Object?> get props => [conversationId, currentUserId, limit];
}

class MessagesUpdatedEvent extends MessagesEvent {
  const MessagesUpdatedEvent(this.messages);

  final List<MessageEntity> messages;

  @override
  List<Object?> get props => [messages];
}

class MessagesStreamErrorEvent extends MessagesEvent {
  const MessagesStreamErrorEvent(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class SendMessageEvent extends MessagesEvent {
  SendMessageEvent({
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = 'text',
    String? clientMessageId,
  }) : clientMessageId =
           clientMessageId ??
           '${DateTime.now().microsecondsSinceEpoch}_$senderId';

  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String type;
  final String clientMessageId;

  @override
  List<Object?> get props => [
    conversationId,
    senderId,
    senderName,
    text,
    type,
    clientMessageId,
  ];
}

class LoadOlderMessagesEvent extends MessagesEvent {
  const LoadOlderMessagesEvent({
    required this.conversationId,
    this.limit = 30,
  });

  final String conversationId;
  final int limit;

  @override
  List<Object?> get props => [conversationId, limit];
}

class MarkAsReadEvent extends MessagesEvent {
  const MarkAsReadEvent({
    required this.conversationId,
    required this.currentUserId,
  });

  final String conversationId;
  final String currentUserId;

  @override
  List<Object?> get props => [conversationId, currentUserId];
}
