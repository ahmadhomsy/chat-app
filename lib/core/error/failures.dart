import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => [];
}

class OfflineFailure extends Failure {
  const OfflineFailure();
}

class NotVerifiedFailure extends Failure {
  const NotVerifiedFailure();
}

class TooManyRequestsFailure extends Failure {
  const TooManyRequestsFailure();
}

class ServerFailure extends Failure {
  const ServerFailure();
}

class EmptyCacheFailure extends Failure {
  const EmptyCacheFailure();
}

class UnExpectedFailure extends Failure {
  const UnExpectedFailure();
}

class SignInFailure extends Failure {
  const SignInFailure();
}

class WeekPasswordFailure extends Failure {
  const WeekPasswordFailure();
}

class AlreadyRegisteredFailure extends Failure {
  const AlreadyRegisteredFailure();
}

class InvalidEmailFailure extends Failure {
  const InvalidEmailFailure();
}

class WrongPasswordFailure extends Failure {
  const WrongPasswordFailure();
}

class UserNotFoundFailure extends Failure {
  const UserNotFoundFailure();
}

class UserDisabledFailure extends Failure {
  const UserDisabledFailure();
}

class RequiresRecentLoginFailure extends Failure {
  const RequiresRecentLoginFailure();
}

class GoogleSignInCancelledFailure extends Failure {
  const GoogleSignInCancelledFailure();
}

class ResetPasswordFailure extends Failure {
  const ResetPasswordFailure();
}

class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure();
}
