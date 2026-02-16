import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:dartz/dartz.dart';

class SignUpUseCase {

  SignUpUseCase(this.repository);
  final AuthRepositories repository;

  Future<Either<Failure, Unit>> call(SignUpRequest request) async {
    return repository.signUp(request);
  }
}
