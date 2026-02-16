import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:dartz/dartz.dart';

class CheckEmailVerifiedUseCase {

  CheckEmailVerifiedUseCase(this.repository);
  final AuthRepositories repository;

  Future<Either<Failure, Unit>> call() async {
    return repository.checkEmailVerified();
  }
}
