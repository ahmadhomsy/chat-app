import 'dart:async';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/mark_as_read_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
    required this.markAsReadUseCase,
    required this.chatRepository,
  }) : super(MessagesInitial()) {
    on<LoadMessagesEvent>(_onLoadMessages);
    on<MessagesUpdatedEvent>(_onMessagesUpdated);
    on<MessagesStreamErrorEvent>(_onMessagesStreamError);
    on<SendMessageEvent>(_onSendMessage);
    on<LoadOlderMessagesEvent>(_onLoadOlderMessages);
    on<MarkAsReadEvent>(_onMarkAsRead);
  }

  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;
  final MarkAsReadUseCase markAsReadUseCase;
  final ChatRepository chatRepository;

  StreamSubscription<List<MessageEntity>>? _messagesSubscription;

  Future<void> _onLoadMessages(
    LoadMessagesEvent event,
    Emitter<MessagesState> emit,
  ) async {
    emit(MessagesLoading());
    await _messagesSubscription?.cancel();

    // Mark as read immediately when conversation is loaded
    unawaited(
      markAsReadUseCase(
        conversationId: event.conversationId,
        currentUserId: event.currentUserId,
      ),
    );

    _messagesSubscription =
        getMessagesUseCase(
          event.conversationId,
          limit: event.limit,
        ).listen(
          (messages) {
            add(MessagesUpdatedEvent(messages));
          },
          onError: (Object error) {
            add(const MessagesStreamErrorEvent(serverErrorMessage));
          },
        );
  }

  void _onMessagesUpdated(
    MessagesUpdatedEvent event,
    Emitter<MessagesState> emit,
  ) {
    if (event.messages.isEmpty) {
      if (state is! MessagesLoaded) {
        emit(MessagesEmpty());
      }
    } else {
      if (state is MessagesLoaded) {
        final current = state as MessagesLoaded;
        // Merge latest stream messages with already paginated older messages
        final messageMap = <String, MessageEntity>{};
        for (final msg in current.messages) {
          messageMap[msg.id] = msg;
        }
        for (final msg in event.messages) {
          messageMap[msg.id] = msg;
        }
        final merged = messageMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        emit(current.copyWith(messages: merged));
      } else {
        emit(
          MessagesLoaded(
            messages: event.messages,
            hasReachedEnd: event.messages.length < 30,
          ),
        );
      }
    }
  }

  void _onMessagesStreamError(
    MessagesStreamErrorEvent event,
    Emitter<MessagesState> emit,
  ) {
    emit(MessagesError(event.message));
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<MessagesState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    if (state is MessagesLoaded) {
      final current = state as MessagesLoaded;
      emit(current.copyWith(isSending: true));
    }

    final result = await sendMessageUseCase(
      conversationId: event.conversationId,
      senderId: event.senderId,
      senderName: event.senderName,
      text: text,
      type: event.type,
    );

    result.fold(
      (failure) {
        if (state is MessagesLoaded) {
          final current = state as MessagesLoaded;
          emit(current.copyWith(isSending: false));
        }
      },
      (_) {
        if (state is MessagesLoaded) {
          final current = state as MessagesLoaded;
          emit(current.copyWith(isSending: false));
        }
      },
    );
  }

  Future<void> _onLoadOlderMessages(
    LoadOlderMessagesEvent event,
    Emitter<MessagesState> emit,
  ) async {
    if (state is! MessagesLoaded) return;
    final currentState = state as MessagesLoaded;
    if (currentState.isLoadingOlder || currentState.hasReachedEnd) return;

    if (currentState.messages.isEmpty) return;
    final oldestDate = currentState.messages.last.createdAt;

    emit(currentState.copyWith(isLoadingOlder: true));

    final result = await chatRepository.loadOlderMessages(
      event.conversationId,
      beforeDate: oldestDate,
      limit: event.limit,
    );

    result.fold(
      (failure) => emit(currentState.copyWith(isLoadingOlder: false)),
      (olderMessages) {
        if (olderMessages.isEmpty) {
          emit(
            currentState.copyWith(
              hasReachedEnd: true,
              isLoadingOlder: false,
            ),
          );
        } else {
          final messageMap = <String, MessageEntity>{};
          for (final msg in currentState.messages) {
            messageMap[msg.id] = msg;
          }
          for (final msg in olderMessages) {
            messageMap[msg.id] = msg;
          }
          final combined = messageMap.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          emit(
            currentState.copyWith(
              messages: combined,
              hasReachedEnd: olderMessages.length < event.limit,
              isLoadingOlder: false,
            ),
          );
        }
      },
    );
  }

  Future<void> _onMarkAsRead(
    MarkAsReadEvent event,
    Emitter<MessagesState> emit,
  ) async {
    await markAsReadUseCase(
      conversationId: event.conversationId,
      currentUserId: event.currentUserId,
    );
  }

  @override
  Future<void> close() async {
    await _messagesSubscription?.cancel();
    return super.close();
  }
}
