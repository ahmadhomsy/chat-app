import 'dart:async';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit({
    required this.getConversationsUseCase,
  }) : super(ConversationsInitial());

  final GetConversationsUseCase getConversationsUseCase;
  StreamSubscription<List<ConversationEntity>>? _subscription;
  String? _currentUserId;
  String? _currentType;

  void loadConversations(String currentUserId, {String? type}) {
    _currentUserId = currentUserId;
    _currentType = type;
    emit(ConversationsLoading());

    unawaited(_subscription?.cancel());
    _subscription = getConversationsUseCase(currentUserId, type: type).listen(
      (conversations) {
        if (conversations.isEmpty) {
          emit(ConversationsEmpty());
        } else {
          emit(ConversationsLoaded(conversations));
        }
      },
      onError: (Object error) {
        emit(const ConversationsError(serverErrorMessage));
      },
    );
  }

  void filterByType(String? type) {
    if (_currentUserId != null) {
      loadConversations(_currentUserId!, type: type);
    }
  }

  void retry() {
    if (_currentUserId != null) {
      loadConversations(_currentUserId!, type: _currentType);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
