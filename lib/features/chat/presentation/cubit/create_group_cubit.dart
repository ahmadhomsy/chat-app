import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/usecases/create_group_conversation_usecase.dart';
import 'package:chat_app/features/chat/presentation/cubit/create_group_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateGroupCubit extends Cubit<CreateGroupState> {
  CreateGroupCubit({
    required this.createGroupConversationUseCase,
  }) : super(const CreateGroupInitial());

  final CreateGroupConversationUseCase createGroupConversationUseCase;

  void toggleMember(UserEntity user) {
    final currentMembers = state is CreateGroupInitial
        ? List<UserEntity>.from((state as CreateGroupInitial).selectedMembers)
        : <UserEntity>[];

    if (currentMembers.any((m) => m.id == user.id)) {
      currentMembers.removeWhere((m) => m.id == user.id);
    } else {
      currentMembers.add(user);
    }

    emit(CreateGroupInitial(selectedMembers: currentMembers));
  }

  Future<void> createGroup({
    required String currentUserId,
    required String groupName,
    String? groupAvatar,
  }) async {
    final name = groupName.trim();
    if (name.isEmpty) {
      emit(const CreateGroupError('يرجى إدخال اسم المجموعة'));
      return;
    }

    final members = state is CreateGroupInitial
        ? (state as CreateGroupInitial).selectedMembers
        : <UserEntity>[];

    if (members.isEmpty) {
      emit(const CreateGroupError('يرجى اختيار عضو واحد على الأقل'));
      return;
    }

    emit(CreateGroupLoading());

    final result = await createGroupConversationUseCase(
      currentUserId: currentUserId,
      groupName: name,
      members: members,
      groupAvatar: groupAvatar,
    );

    result.fold(
      (failure) => emit(const CreateGroupError(serverErrorMessage)),
      (conversation) => emit(CreateGroupSuccess(conversation)),
    );
  }
}
