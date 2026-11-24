import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:equatable/equatable.dart';

abstract class CreateGroupState extends Equatable {
  const CreateGroupState();

  @override
  List<Object?> get props => [];
}

class CreateGroupInitial extends CreateGroupState {
  const CreateGroupInitial({this.selectedMembers = const []});

  final List<UserEntity> selectedMembers;

  @override
  List<Object?> get props => [selectedMembers];
}

class CreateGroupLoading extends CreateGroupState {}

class CreateGroupSuccess extends CreateGroupState {
  const CreateGroupSuccess(this.conversation);

  final ConversationEntity conversation;

  @override
  List<Object?> get props => [conversation];
}

class CreateGroupError extends CreateGroupState {
  const CreateGroupError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
