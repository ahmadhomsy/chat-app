import 'package:equatable/equatable.dart';

class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.senderName,
    this.type = 'text',
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String text;
  final String type;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  bool isMine(String currentUserId) => senderId == currentUserId;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    senderName,
    text,
    type,
    createdAt,
    editedAt,
    deletedAt,
  ];
}
