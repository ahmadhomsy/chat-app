import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/features/auth/data/models/user_model.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/data/data_sources/chat_remote_data_source.dart';
import 'package:chat_app/features/chat/data/models/conversation_model.dart';
import 'package:chat_app/features/chat/data/models/message_model.dart';
import 'package:chat_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});
  bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class FakeChatRemoteDataSource implements ChatRemoteDataSource {
  bool throwPermissionDenied = false;
  bool throwServerException = false;

  @override
  Stream<List<ConversationModel>> getConversationsStream(
    String currentUserId, {
    String? type,
  }) {
    return Stream.value([
      ConversationModel(
        id: 'conv_1',
        type: 'direct',
        participantIds: [currentUserId, 'other_uid'],
        createdBy: currentUserId,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Stream<List<MessageModel>> getMessagesStream(
    String conversationId, {
    int limit = 30,
  }) {
    return Stream.value([
      MessageModel(
        id: 'msg_1',
        conversationId: conversationId,
        senderId: 'user1',
        text: 'Hello',
        createdAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<List<MessageModel>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 30,
  }) async {
    if (throwServerException) throw ServerException();
    return [];
  }

  @override
  Future<ConversationModel> getOrCreateDirectConversation({
    required String currentUserId,
    required UserEntity otherUser,
  }) async {
    if (throwPermissionDenied) throw PermissionDeniedException();
    return ConversationModel(
      id: '${currentUserId}_${otherUser.id}',
      type: 'direct',
      participantIds: [currentUserId, otherUser.id],
      createdBy: currentUserId,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<ConversationModel> createGroupConversation({
    required String currentUserId,
    required String groupName,
    required List<UserEntity> members,
    String? groupAvatar,
  }) async {
    if (throwServerException) throw ServerException();
    return ConversationModel(
      id: 'group_1',
      type: 'group',
      groupName: groupName,
      participantIds: [currentUserId, ...members.map((m) => m.id)],
      createdBy: currentUserId,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Unit> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) async {
    if (throwServerException) throw ServerException();
    return unit;
  }

  @override
  Future<Unit> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    return unit;
  }

  @override
  Future<List<UserModel>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    return const [
      UserModel(id: 'found_1', name: 'Found User', email: 'found@example.com'),
    ];
  }

  @override
  Future<List<UserModel>> getAllUsers({
    required String currentUserId,
    int limit = 50,
  }) async {
    return const [
      UserModel(id: 'user_a', name: 'User A', email: 'a@example.com'),
    ];
  }
}

void main() {
  late ChatRepositoryImpl repository;
  late FakeChatRemoteDataSource fakeDataSource;
  late FakeNetworkInfo fakeNetworkInfo;

  setUp(() {
    fakeDataSource = FakeChatRemoteDataSource();
    fakeNetworkInfo = FakeNetworkInfo();
    repository = ChatRepositoryImpl(
      remoteDataSource: fakeDataSource,
      networkInfo: fakeNetworkInfo,
    );
  });

  group('ChatRepositoryImpl Tests', () {
    test('should return OfflineFailure when network is offline', () async {
      fakeNetworkInfo.connected = false;

      final result = await repository.sendMessage(
        conversationId: 'c1',
        senderId: 'u1',
        senderName: 'U1',
        text: 'Hi',
      );

      expect(result, equals(const Left<Failure, Unit>(OfflineFailure())));
    });

    test(
      'should map PermissionDeniedException to PermissionDeniedFailure',
      () async {
        fakeDataSource.throwPermissionDenied = true;

        final result = await repository.getOrCreateDirectConversation(
          currentUserId: 'u1',
          otherUser: const UserEntity(
            id: 'u2',
            name: 'U2',
            email: 'u2@test.com',
          ),
        );

        expect(
          result,
          equals(
            const Left<Failure, ConversationEntity>(PermissionDeniedFailure()),
          ),
        );
      },
    );

    test('should execute sendMessage successfully when online', () async {
      final result = await repository.sendMessage(
        conversationId: 'c1',
        senderId: 'u1',
        senderName: 'U1',
        text: 'Hello world',
      );

      expect(result, equals(const Right<Failure, Unit>(unit)));
    });

    test('should create group conversation successfully', () async {
      final result = await repository.createGroupConversation(
        currentUserId: 'u1',
        groupName: 'Flutter Team',
        members: [const UserEntity(id: 'u2', name: 'U2', email: 'u2@test.com')],
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected right'),
        (conv) {
          expect(conv.isGroup, isTrue);
          expect(conv.groupName, equals('Flutter Team'));
        },
      );
    });
  });
}
