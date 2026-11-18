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
      return const Left(OfflineFailure());
    }

    try {
      final result = await action();
      return Right(result);
    } on AlreadyRegisteredException {
      return const Left(AlreadyRegisteredFailure());
    } on WeekPasswordException {
      return const Left(WeekPasswordFailure());
    } on SignInException {
      return const Left(SignInFailure());
    } on WrongPasswordException {
      return const Left(WrongPasswordFailure());
    } on UserNotFoundException {
      return const Left(UserNotFoundFailure());
    } on UserDisabledException {
      return const Left(UserDisabledFailure());
    } on InvalidEmailException {
      return const Left(InvalidEmailFailure());
    } on TooManyRequestsException {
      return const Left(TooManyRequestsFailure());
    } on ServerException {
      return const Left(ServerFailure());
    } on NotVerifiedException {
      return const Left(NotVerifiedFailure());
    } on RequiresRecentLoginException {
      return const Left(RequiresRecentLoginFailure());
    } on GoogleSignInCancelledException {
      return const Left(GoogleSignInCancelledFailure());
    } on OfflineException {
      return const Left(OfflineFailure());
    } on UnExpectedException {
      return const Left(UnExpectedFailure());
    } on Object catch (_) {
      return const Left(UnExpectedFailure());
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

  @override
  Future<Either<Failure, Unit>> resetPassword(String email) {
    return _execute(() => data.resetPassword(email));
  }
}
