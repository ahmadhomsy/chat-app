import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:equatable/equatable.dart';

abstract class MessagesState extends Equatable {
  const MessagesState();

  @override
  List<Object?> get props => [];
}

class MessagesInitial extends MessagesState {}

class MessagesLoading extends MessagesState {}

class MessagesLoaded extends MessagesState {
  const MessagesLoaded({
    required this.messages,
    this.hasReachedEnd = false,
    this.isLoadingOlder = false,
    this.isSending = false,
  });

  final List<MessageEntity> messages;
  final bool hasReachedEnd;
  final bool isLoadingOlder;
  final bool isSending;

  MessagesLoaded copyWith({
    List<MessageEntity>? messages,
    bool? hasReachedEnd,
    bool? isLoadingOlder,
    bool? isSending,
  }) {
    return MessagesLoaded(
      messages: messages ?? this.messages,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    hasReachedEnd,
    isLoadingOlder,
    isSending,
  ];
}

class MessagesEmpty extends MessagesState {}

class MessagesError extends MessagesState {
  const MessagesError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
