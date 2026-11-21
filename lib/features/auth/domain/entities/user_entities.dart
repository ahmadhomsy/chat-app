import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.phone,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.provider = 'email',
  });

  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? phone;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final String provider;

  /// Backwards compatibility alias for code expecting `username`
  String get username => name;

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    photoUrl,
    phone,
    isOnline,
    lastSeen,
    createdAt,
    provider,
  ];
}
