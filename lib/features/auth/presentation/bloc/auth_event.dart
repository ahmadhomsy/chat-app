part of 'auth_bloc.dart';

@immutable
sealed class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SignInEvent extends AuthEvent {
  SignInEvent({required this.request});
  final SignInRequest request;
  @override
  List<Object> get props => [request];
}

class SignUpEvent extends AuthEvent {
  SignUpEvent({required this.request});
  final SignUpRequest request;
  @override
  List<Object> get props => [request];
}

class SignByGoogleEvent extends AuthEvent {}

class DeleteAccountEvent extends AuthEvent {}

class CheckVerifiedEvent extends AuthEvent {}

class SendEmailVerificationEvent extends AuthEvent {}

class EmailChanged extends AuthEvent {
  EmailChanged(this.value);
  final String value;
}

class PasswordChanged extends AuthEvent {
  PasswordChanged(this.value);
  final String value;
}

class TogglePasswordVisibility extends AuthEvent {}
