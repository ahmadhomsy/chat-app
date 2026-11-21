part of 'auth_bloc.dart';

@immutable
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class DeleteLoading extends AuthState {
  const DeleteLoading();
}

class LogoutLoading extends AuthState {
  const LogoutLoading();
}

class ResetPasswordLoading extends AuthState {
  const ResetPasswordLoading();
}

class AuthError extends AuthState {
  const AuthError({required this.message});
  final String message;

  @override
  List<Object> get props => [message];
}

class AuthSuccess extends AuthState {
  const AuthSuccess();
}

class SignUpSuccess extends AuthState {
  const SignUpSuccess();
}

class AuthNeedsEmailVerification extends AuthState {
  const AuthNeedsEmailVerification();
}

class GoogleSuccess extends AuthState {
  const GoogleSuccess();
}

class DeleteSuccess extends AuthState {
  const DeleteSuccess();
}

class LogoutSuccess extends AuthState {
  const LogoutSuccess();
}

class VerifiedSuccess extends AuthState {
  const VerifiedSuccess();
}

class VerificationEmailSentSuccess extends AuthState {
  const VerificationEmailSentSuccess();
}

class ResetPasswordSuccess extends AuthState {
  const ResetPasswordSuccess();
}
