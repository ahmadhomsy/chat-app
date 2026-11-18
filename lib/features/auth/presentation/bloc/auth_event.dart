part of 'auth_bloc.dart';

@immutable
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SignInEvent extends AuthEvent {
  const SignInEvent({required this.request});
  final SignInRequest request;

  @override
  List<Object> get props => [request];
}

class SignUpEvent extends AuthEvent {
  const SignUpEvent({required this.request});
  final SignUpRequest request;

  @override
  List<Object> get props => [request];
}

class SignByGoogleEvent extends AuthEvent {
  const SignByGoogleEvent();
}

class DeleteAccountEvent extends AuthEvent {
  const DeleteAccountEvent();
}

class CheckVerifiedEvent extends AuthEvent {
  const CheckVerifiedEvent();
}

class SendEmailVerificationEvent extends AuthEvent {
  const SendEmailVerificationEvent();
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

class ResetPasswordEvent extends AuthEvent {
  const ResetPasswordEvent({required this.email});
  final String email;

  @override
  List<Object> get props => [email];
}
