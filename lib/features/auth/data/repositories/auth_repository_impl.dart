import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/features/auth/data/data_sources/firebase_auth_data_source.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:dartz/dartz.dart';

class AuthRepositoryImpl implements AuthRepositories {

  AuthRepositoryImpl({required this.data, required this.networkInfo});
  final FirebaseAuthDataSource data;
  final NetworkInfo networkInfo;

  Future<Either<Failure, T>> _execute<T>(Future<T> Function() action) async {
    if (!await networkInfo.isConnected) {
      return Left(OfflineFailure());
    }

    try {
      final result = await action();
      return Right(result);
    } on AlreadyRegisteredException {
      return Left(AlreadyRegisteredFailure());
    } on WeekPasswordException {
      return Left(WeekPasswordFailure());
    } on SignInException {
      return Left(SignInFailure());
    } on TooManyRequestsException {
      return Left(TooManyRequestsFailure());
    } on ServerException {
      return Left(ServerFailure());
    } on NotVerifiedException {
      return Left(NotVerifiedFailure());
    } on UnExpectedException {
      return Left(UnExpectedFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signUp(SignUpRequest request) {
    return _execute(() => data.signUp(request));
  }

  @override
  Future<Either<Failure, Unit>> signIn(SignInRequest request) {
    return _execute(() => data.signIn(request));
  }

  @override
  Future<Either<Failure, Unit>> logout() {
    return _execute(data.logout);
  }

  @override
  Future<Either<Failure, bool>> loggedIn() async {
    return _execute(data.loggedIn);
  }

  @override
  Future<Either<Failure, Unit>> signGoogle() {
    return _execute(data.signGoogle);
  }

  @override
  Future<Either<Failure, Unit>> sendEmailVerification() {
    return _execute(data.sendEmailVerification);
  }

  @override
  Future<Either<Failure, Unit>> checkEmailVerified() {
    return _execute(data.checkEmailVerified);
  }

  @override
  Future<Either<Failure, Unit>> deleteAccount() {
    return _execute(data.deleteAccount);
  }
}
