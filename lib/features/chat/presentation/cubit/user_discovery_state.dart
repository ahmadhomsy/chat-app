import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:equatable/equatable.dart';

abstract class UserDiscoveryState extends Equatable {
  const UserDiscoveryState();

  @override
  List<Object?> get props => [];
}

class UserDiscoveryInitial extends UserDiscoveryState {}

class UserDiscoveryLoading extends UserDiscoveryState {}

class UserDiscoveryLoaded extends UserDiscoveryState {
  const UserDiscoveryLoaded(this.users);

  final List<UserEntity> users;

  @override
  List<Object?> get props => [users];
}

class UserDiscoveryEmpty extends UserDiscoveryState {}

class UserDiscoveryError extends UserDiscoveryState {
  const UserDiscoveryError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
