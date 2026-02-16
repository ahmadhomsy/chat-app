part of 'auth_bloc.dart';

@immutable
sealed class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class DeleteLoading extends AuthState {}

class AuthError extends AuthState {
  AuthError({required this.message});
  final String message;
  @override
  List<Object> get props => [message];
}

class AuthSuccess extends AuthState {}

class GoogleSuccess extends AuthState {}

class DeleteSuccess extends AuthState {}

class VerifiedSuccess extends AuthState {}
