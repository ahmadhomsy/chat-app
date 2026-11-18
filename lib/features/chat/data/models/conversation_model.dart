import 'package:chat_app/features/chat/data/models/chat_participant_model.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.type,
    required super.participantIds,
    required super.createdBy,
    required super.createdAt,
    super.participants = const {},
    super.updatedAt,
    super.lastMessage,
    super.lastMessageAt,
    super.lastMessageSenderId,
    super.lastMessageSenderName,
    super.groupName,
    super.groupAvatar,
    super.adminIds = const [],
    super.lastReadAtByUser = const {},
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
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

    final participantIdsList =
        (map['participantIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final participantsRaw = map['participants'] as Map<String, dynamic>? ?? {};
    final participantsMap = <String, ChatParticipantModel>{};
    participantsRaw.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        participantsMap[k] = ChatParticipantModel.fromMap(v, k);
      }
    });

    final adminIdsList =
        (map['adminIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final lastReadRaw = map['lastReadAtByUser'] as Map<String, dynamic>? ?? {};
    final lastReadMap = <String, DateTime>{};
    lastReadRaw.forEach((k, v) {
      final parsed = parseNullableTimestamp(v);
      if (parsed != null) {
        lastReadMap[k] = parsed;
      }
    });

    return ConversationModel(
      id: id,
      type: (map['type'] as String?) ?? 'direct',
      participantIds: participantIdsList,
      participants: participantsMap,
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseNullableTimestamp(map['updatedAt']),
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: parseNullableTimestamp(map['lastMessageAt']),
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      lastMessageSenderName: map['lastMessageSenderName'] as String?,
      groupName: map['groupName'] as String?,
      groupAvatar: map['groupAvatar'] as String?,
      adminIds: adminIdsList,
      lastReadAtByUser: lastReadMap,
    );
  }

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ConversationModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    final participantsMap = <String, dynamic>{};
    participants.forEach((k, v) {
      if (v is ChatParticipantModel) {
        participantsMap[k] = v.toMap();
      } else {
        participantsMap[k] = {
          'id': v.id,
          'name': v.name,
          'photoUrl': v.photoUrl,
          'isOnline': v.isOnline,
        };
      }
    });

    final lastReadMap = <String, dynamic>{};
    lastReadAtByUser.forEach((k, v) {
      lastReadMap[k] = Timestamp.fromDate(v);
    });

    return {
      'type': type,
      'participantIds': participantIds,
      'participants': participantsMap,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      if (lastMessageSenderId != null)
        'lastMessageSenderId': lastMessageSenderId,
      if (lastMessageSenderName != null)
        'lastMessageSenderName': lastMessageSenderName,
      if (groupName != null) 'groupName': groupName,
      if (groupAvatar != null) 'groupAvatar': groupAvatar,
      'adminIds': adminIds,
      'lastReadAtByUser': lastReadMap,
    };
  }
}
