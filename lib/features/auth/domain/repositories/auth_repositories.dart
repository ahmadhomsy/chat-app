import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:dartz/dartz.dart';

abstract class AuthRepositories {
  Future<Either<Failure, Unit>> signGoogle();
  Future<Either<Failure, Unit>> checkEmailVerified();
  Future<Either<Failure, Unit>> sendEmailVerification();
  Future<Either<Failure, Unit>> signIn(SignInRequest request);
  Future<Either<Failure, Unit>> signUp(SignUpRequest request);
  Future<Either<Failure, Unit>> logout();
  Future<Either<Failure, Unit>> deleteAccount();
  Future<Either<Failure, bool>> loggedIn();
}
