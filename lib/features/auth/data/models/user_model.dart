import 'package:chat_app/features/auth/domain/entities/user_entities.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.username,
    required super.phone,
  });

  // factory UserModel.fromFirebase(User user) {
  //   return UserModel(
  //     id: user.id,
  //     phone: user.phone ?? "",
  //     username: user.userMetadata?['username'] ?? "",
  //   );
  // }
}
