import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.text,
    required super.createdAt,
    super.senderName,
    super.type = 'text',
    super.editedAt,
    super.deletedAt,
  });

  factory MessageModel.fromMap(
    Map<String, dynamic> map,
    String id,
    String conversationId,
  ) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableTimestamp(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: (map['senderId'] as String?) ?? '',
      senderName: map['senderName'] as String?,
      text: (map['text'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'text',
      createdAt: parseTimestamp(map['createdAt']),
      editedAt: parseNullableTimestamp(map['editedAt']),
      deletedAt: parseNullableTimestamp(map['deletedAt']),
    );
  }

  factory MessageModel.fromFirestore(
    DocumentSnapshot doc,
    String conversationId,
  ) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return MessageModel.fromMap(data, doc.id, conversationId);
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      'text': text,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }
}
