import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:dartz/dartz.dart';

class SignInUseCase {

  SignInUseCase(this.repository);
  final AuthRepositories repository;

  Future<Either<Failure, Unit>> call(SignInRequest request) async {
    return repository.signIn(request);
  }
}
