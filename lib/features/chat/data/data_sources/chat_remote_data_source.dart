import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/features/auth/data/models/user_model.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/data/models/chat_participant_model.dart';
import 'package:chat_app/features/chat/data/models/conversation_model.dart';
import 'package:chat_app/features/chat/data/models/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

abstract class ChatRemoteDataSource {
  Stream<List<ConversationModel>> getConversationsStream(
    String currentUserId, {
    String? type,
  });

  Stream<List<MessageModel>> getMessagesStream(
    String conversationId, {
    int limit = 30,
  });

  Future<List<MessageModel>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  });

  Future<ConversationModel> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  });

  Future<ConversationModel> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  });

  Future<Unit> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  });

  Future<Unit> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  });

  Future<List<UserModel>> searchUsers({
    required String query,
    required String currentUserId,
  });

  Future<List<UserModel>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static String getDirectConversationId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  @override
  Stream<List<ConversationModel>> getConversationsStream(
    String currentUserId, {
    String? type,
  }) {
    try {
      var query = _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId);

      if (type != null && type.isNotEmpty) {
        query = query.where('type', isEqualTo: type);
      }

      return query.orderBy('updatedAt', descending: true).snapshots().map((
        snapshot,
      ) {
        return snapshot.docs.map(ConversationModel.fromFirestore).toList();
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    }
  }

  @override
  Stream<List<MessageModel>> getMessagesStream(
    String conversationId, {
    int limit = 30,
  }) {
    try {
      return _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => MessageModel.fromFirestore(doc, conversationId))
                .toList();
          });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    }
  }

  @override
  Future<List<MessageModel>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('createdAt', isLessThan: Timestamp.fromDate(beforeDate))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc, conversationId))
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<ConversationModel> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  }) async {
    if (currentUserId == otherUser.id) {
      throw ServerException();
    }
    try {
      final conversationId = getDirectConversationId(
        currentUserId,
        otherUser.id,
      );
      final conversationDoc = _firestore
          .collection('conversations')
          .doc(conversationId);

      final snapshot = await conversationDoc.get();

      if (snapshot.exists) {
        return ConversationModel.fromFirestore(snapshot);
      }

      // Fetch current user details from Firestore to populate participants map
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserName =
          (currentUserDoc.data()?['name'] as String?)?.trim() ?? 'Me';
      final currentUserPhoto = currentUserDoc.data()?['photoUrl'] as String?;

      final now = DateTime.now();
      final conversationModel = ConversationModel(
        id: conversationId,
        type: 'direct',
        participantIds: [currentUserId, otherUser.id],
        createdBy: currentUserId,
        createdAt: now,
        updatedAt: now,
        participants: {
          currentUserId: ChatParticipantModel(
            id: currentUserId,
            name: currentUserName,
            photoUrl: currentUserPhoto,
            email: currentUserDoc.data()?['email'] as String?,
          ),
          otherUser.id: ChatParticipantModel(
            id: otherUser.id,
            name: otherUser.name,
            photoUrl: otherUser.photoUrl,
            email: otherUser.email,
            isOnline: otherUser.isOnline,
            lastSeen: otherUser.lastSeen,
          ),
        },
        adminIds: [currentUserId],
        lastReadAtByUser: {
          currentUserId: now,
        },
      );

      await conversationDoc.set(conversationModel.toMap());
      return conversationModel;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<ConversationModel> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) async {
    try {
      final conversationDoc = _firestore.collection('conversations').doc();
      final conversationId = conversationDoc.id;

      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserName =
          (currentUserDoc.data()?['name'] as String?)?.trim() ?? 'Me';
      final currentUserPhoto = currentUserDoc.data()?['photoUrl'] as String?;

      final participantIds = <String>[currentUserId];
      final participantsMap = <String, ChatParticipantModel>{
        currentUserId: ChatParticipantModel(
          id: currentUserId,
          name: currentUserName,
          photoUrl: currentUserPhoto,
          email: currentUserDoc.data()?['email'] as String?,
        ),
      };

      for (final member in members) {
        if (!participantIds.contains(member.id)) {
          participantIds.add(member.id);
          participantsMap[member.id] = ChatParticipantModel(
            id: member.id,
            name: member.name,
            photoUrl: member.photoUrl,
            email: member.email,
            isOnline: member.isOnline,
            lastSeen: member.lastSeen,
          );
        }
      }

      final now = DateTime.now();
      final conversationModel = ConversationModel(
        id: conversationId,
        type: 'group',
        groupName: groupName.trim(),
        groupAvatar: groupAvatar,
        participantIds: participantIds,
        participants: participantsMap,
        createdBy: currentUserId,
        adminIds: [currentUserId],
        createdAt: now,
        updatedAt: now,
        lastReadAtByUser: {
          currentUserId: now,
        },
      );

      await conversationDoc.set(conversationModel.toMap());
      return conversationModel;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<Unit> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) async {
    try {
      final batch = _firestore.batch();
      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);
      final messageRef = conversationRef.collection('messages').doc();

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'text': text.trim(),
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(messageRef, messageData);

      final conversationUpdates = {
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'lastMessageSenderName': senderName,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastReadAtByUser.$senderId': FieldValue.serverTimestamp(),
      };

      batch.update(conversationRef, conversationUpdates);

      await batch.commit();
      return unit;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<Unit> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastReadAtByUser.$currentUserId': FieldValue.serverTimestamp(),
      });
      return unit;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<List<UserModel>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) {
        return getAllUsers(currentUserId: currentUserId, limit: 20);
      }

      // 1. Direct match by exact email (avoids exposing entire directory)
      if (trimmedQuery.contains('@')) {
        final emailSnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: trimmedQuery.toLowerCase())
            .limit(1)
            .get();

        if (emailSnapshot.docs.isNotEmpty) {
          return emailSnapshot.docs
              .map(UserModel.fromFirestore)
              .where((user) => user.id != currentUserId)
              .toList();
        }
      }

      // 2. Prefix query by name
      final nameSnapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: trimmedQuery)
          .where('name', isLessThanOrEqualTo: '$trimmedQuery\uf8ff')
          .limit(20)
          .get();

      if (nameSnapshot.docs.isNotEmpty) {
        return nameSnapshot.docs
            .map(UserModel.fromFirestore)
            .where((user) => user.id != currentUserId)
            .toList();
      }

      // 3. Fallback scoped scan on recent users
      final snapshot = await _firestore.collection('users').limit(50).get();
      final lower = trimmedQuery.toLowerCase();
      return snapshot.docs
          .map(UserModel.fromFirestore)
          .where((user) => user.id != currentUserId)
          .where(
            (user) =>
                user.name.toLowerCase().contains(lower) ||
                user.email.toLowerCase().contains(lower),
          )
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }

  @override
  Future<List<UserModel>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore.collection('users').limit(limit).get();

      return snapshot.docs
          .map(UserModel.fromFirestore)
          .where((user) => user.id != currentUserId)
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionDeniedException();
      }
      throw ServerException();
    } on Object catch (_) {
      throw ServerException();
    }
  }
}
