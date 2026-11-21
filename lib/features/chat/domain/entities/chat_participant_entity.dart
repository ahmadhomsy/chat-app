import 'package:equatable/equatable.dart';

class ChatParticipantEntity extends Equatable {
  const ChatParticipantEntity({
    required this.id,
    required this.name,
    this.email,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String? email;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  @override
  List<Object?> get props => [id, name, email, photoUrl, isOnline, lastSeen];
}
