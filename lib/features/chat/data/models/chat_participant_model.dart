import 'package:chat_app/features/chat/domain/entities/chat_participant_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatParticipantModel extends ChatParticipantEntity {
  const ChatParticipantModel({
    required super.id,
    required super.name,
    super.email,
    super.photoUrl,
    super.isOnline = false,
    super.lastSeen,
  });

  factory ChatParticipantModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ChatParticipantModel(
      id: id,
      name: (map['name'] as String?)?.trim() ?? 'User',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: parseTimestamp(map['lastSeen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (email != null) 'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
    };
  }
}
