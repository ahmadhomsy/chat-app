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
      // Backwards-compatibility read: existing conversation snapshots may contain email
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isOnline: (map['isOnline'] as bool?) ?? false,
      lastSeen: parseTimestamp(map['lastSeen']),
    );
  }

  /// Serializes participant snapshot to Firestore.
  /// PRIVACY REMEDIATION (Phase 4.1):
  /// Participant email addresses are strictly excluded from serialization to prevent
  /// leaking private user emails to other conversation or group members.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
    };
  }
}
