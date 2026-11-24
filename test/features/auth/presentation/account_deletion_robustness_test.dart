import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/features/auth/data/data_sources/firebase_auth_data_source.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class MockNetworkInfo implements NetworkInfo {
  bool connected = true;
  @override
  Future<bool> get isConnected async => connected;
}

class MockAuthDataSource implements FirebaseAuthDataSource {
  bool throwRequiresRecentLogin = false;
  bool throwServerException = false;
  bool deleteAccountCalled = false;
  int deleteAttempts = 0;

  @override
  String? get currentUserId => 'user_123';

  @override
  Future<Unit> deleteAccount() async {
    deleteAttempts++;
    deleteAccountCalled = true;

    if (throwRequiresRecentLogin) {
      throw RequiresRecentLoginException();
    }
    if (throwServerException) {
      throw ServerException();
    }
    return unit;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthDataSource mockDataSource;
  late MockNetworkInfo mockNetworkInfo;

  setUp(() {
    mockDataSource = MockAuthDataSource();
    mockNetworkInfo = MockNetworkInfo();
    repository = AuthRepositoryImpl(
      data: mockDataSource,
      networkInfo: mockNetworkInfo,
    );
  });

  group('Account Deletion Robustness Tests', () {
    test(
      'returns RequiresRecentLoginFailure when session requires fresh auth',
      () async {
        mockDataSource.throwRequiresRecentLogin = true;

        final result = await repository.deleteAccount();

        expect(
          result,
          equals(const Left<Failure, Unit>(RequiresRecentLoginFailure())),
        );
        expect(mockDataSource.deleteAttempts, equals(1));
      },
    );

    test('retry succeeds after user re-authenticates', () async {
      // 1. Initial attempt fails requiring re-authentication
      mockDataSource.throwRequiresRecentLogin = true;
      final firstAttempt = await repository.deleteAccount();
      expect(
        firstAttempt,
        equals(const Left<Failure, Unit>(RequiresRecentLoginFailure())),
      );

      // 2. User re-authenticates (mock flag cleared)
      mockDataSource.throwRequiresRecentLogin = false;

      // 3. Retry succeeds
      final secondAttempt = await repository.deleteAccount();
      expect(secondAttempt, equals(const Right<Failure, Unit>(unit)));
      expect(mockDataSource.deleteAttempts, equals(2));
    });

    test(
      'returns OfflineFailure when network is lost during deletion request',
      () async {
        mockNetworkInfo.connected = false;

        final result = await repository.deleteAccount();

        expect(result, equals(const Left<Failure, Unit>(OfflineFailure())));
        expect(mockDataSource.deleteAccountCalled, isFalse);
      },
    );

    test('returns ServerFailure when remote server returns an error', () async {
      mockDataSource.throwServerException = true;

      final result = await repository.deleteAccount();

      expect(result, equals(const Left<Failure, Unit>(ServerFailure())));
    });
  });
}
