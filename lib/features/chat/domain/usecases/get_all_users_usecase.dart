import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:dartz/dartz.dart';

class GetAllUsersUseCase {
  GetAllUsersUseCase(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, List<UserEntity>>> call({
    required String currentUserId,
    int limit = 50,
  }) {
    return repository.getAllUsers(
      currentUserId: currentUserId,
      limit: limit,
    );
  }
}
