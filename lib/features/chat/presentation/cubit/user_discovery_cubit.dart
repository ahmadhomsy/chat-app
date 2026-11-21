import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/features/chat/domain/usecases/get_all_users_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/search_users_usecase.dart';
import 'package:chat_app/features/chat/presentation/cubit/user_discovery_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserDiscoveryCubit extends Cubit<UserDiscoveryState> {
  UserDiscoveryCubit({
    required this.getAllUsersUseCase,
    required this.searchUsersUseCase,
  }) : super(UserDiscoveryInitial());

  final GetAllUsersUseCase getAllUsersUseCase;
  final SearchUsersUseCase searchUsersUseCase;

  Future<void> loadUsers(String currentUserId) async {
    emit(UserDiscoveryLoading());

    final result = await getAllUsersUseCase(currentUserId: currentUserId);

    result.fold(
      (failure) => emit(const UserDiscoveryError(serverErrorMessage)),
      (users) {
        if (users.isEmpty) {
          emit(UserDiscoveryEmpty());
        } else {
          emit(UserDiscoveryLoaded(users));
        }
      },
    );
  }

  Future<void> search(String currentUserId, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await loadUsers(currentUserId);
      return;
    }

    emit(UserDiscoveryLoading());

    final result = await searchUsersUseCase(
      query: trimmed,
      currentUserId: currentUserId,
    );

    result.fold(
      (failure) => emit(const UserDiscoveryError(serverErrorMessage)),
      (users) {
        if (users.isEmpty) {
          emit(UserDiscoveryEmpty());
        } else {
          emit(UserDiscoveryLoaded(users));
        }
      },
    );
  }
}
