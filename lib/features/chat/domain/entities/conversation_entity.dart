import 'package:chat_app/features/chat/domain/entities/chat_participant_entity.dart';
import 'package:equatable/equatable.dart';

class ConversationEntity extends Equatable {
  const ConversationEntity({
    required this.id,
    required this.type,
    required this.participantIds,
    required this.createdBy,
    required this.createdAt,
    this.participants = const {},
    this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.groupName,
    this.groupAvatar,
    this.adminIds = const [],
    this.lastReadAtByUser = const {},
  });

  final String id;

  /// 'direct' or 'group'
  final String type;
  final List<String> participantIds;
  final Map<String, ChatParticipantEntity> participants;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  final String? groupName;
  final String? groupAvatar;
  final List<String> adminIds;
  final Map<String, DateTime> lastReadAtByUser;

  bool get isGroup => type == 'group';

  String getDisplayName(String currentUserId) {
    if (isGroup) {
      return groupName ?? 'Group Chat';
    }
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (participants.containsKey(otherParticipantId)) {
      return participants[otherParticipantId]?.name ?? 'Direct Chat';
    }
    return 'Direct Chat';
  }

  String? getDisplayAvatar(String currentUserId) {
    if (isGroup) {
      return groupAvatar;
    }
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return participants[otherParticipantId]?.photoUrl;
  }

  bool isOtherUserOnline(String currentUserId) {
    if (isGroup) return false;
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return participants[otherParticipantId]?.isOnline ?? false;
  }

  bool hasUnreadMessages(String currentUserId) {
    if (lastMessageAt == null) return false;
    if (lastMessageSenderId == currentUserId) return false;
    final lastRead = lastReadAtByUser[currentUserId];
    if (lastRead == null) return true;
    return lastMessageAt!.isAfter(lastRead);
  }

  bool isUnreadFor(String currentUserId) => hasUnreadMessages(currentUserId);

  ConversationEntity copyWith({
    String? id,
    String? type,
    List<String>? participantIds,
    Map<String, ChatParticipantEntity>? participants,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    String? groupName,
    String? groupAvatar,
    List<String>? adminIds,
    Map<String, DateTime>? lastReadAtByUser,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      participantIds: participantIds ?? this.participantIds,
      participants: participants ?? this.participants,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName:
          lastMessageSenderName ?? this.lastMessageSenderName,
      groupName: groupName ?? this.groupName,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      adminIds: adminIds ?? this.adminIds,
      lastReadAtByUser: lastReadAtByUser ?? this.lastReadAtByUser,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    participantIds,
    participants,
    createdBy,
    createdAt,
    updatedAt,
    lastMessage,
    lastMessageAt,
    lastMessageSenderId,
    lastMessageSenderName,
    groupName,
    groupAvatar,
    adminIds,
    lastReadAtByUser,
  ];
}
