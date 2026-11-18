import 'package:chat_app/core/error/exceptions.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/features/auth/data/data_sources/firebase_auth_data_source.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});
  bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class FakeFirebaseAuthDataSource implements FirebaseAuthDataSource {
  bool throwInvalidEmail = false;
  bool throwRequiresRecentLogin = false;
  bool throwNotVerified = false;
  bool throwTooManyRequests = false;
  bool throwGoogleCancelled = false;
  bool throwServerException = false;

  @override
  String? get currentUserId => 'test_uid';

  @override
  Future<Unit> signIn(SignInRequest request) async {
    if (throwInvalidEmail) throw InvalidEmailException();
    if (throwNotVerified) throw NotVerifiedException();
    if (throwServerException) throw ServerException();
    return unit;
  }

  @override
  Future<Unit> signUp(SignUpRequest request) async {
    if (throwInvalidEmail) throw InvalidEmailException();
    if (throwTooManyRequests) throw TooManyRequestsException();
    return unit;
  }

  @override
  Future<Unit> logout() async {
    if (throwServerException) throw ServerException();
    return unit;
  }

  @override
  Future<Unit> deleteAccount() async {
    if (throwRequiresRecentLogin) throw RequiresRecentLoginException();
    if (throwServerException) throw ServerException();
    return unit;
  }

  @override
  Future<Unit> resetPassword(String email) async {
    if (throwInvalidEmail) throw InvalidEmailException();
    return unit;
  }

  @override
  Future<Unit> signGoogle() async {
    if (throwGoogleCancelled) throw GoogleSignInCancelledException();
    return unit;
  }

  @override
  Future<Unit> checkEmailVerified() async {
    if (throwNotVerified) throw NotVerifiedException();
    return unit;
  }

  @override
  Future<Unit> sendEmailVerification() async {
    if (throwTooManyRequests) throw TooManyRequestsException();
    return unit;
  }

  @override
  Future<bool> loggedIn() async {
    if (throwNotVerified) throw NotVerifiedException();
    return true;
  }
}

void main() {
  late AuthRepositoryImpl repository;
  late FakeFirebaseAuthDataSource fakeDataSource;
  late FakeNetworkInfo fakeNetworkInfo;

  setUp(() {
    fakeDataSource = FakeFirebaseAuthDataSource();
    fakeNetworkInfo = FakeNetworkInfo();
    repository = AuthRepositoryImpl(
      data: fakeDataSource,
      networkInfo: fakeNetworkInfo,
    );
  });

  group('AuthRepositoryImpl Tests', () {
    test('should return OfflineFailure when network is disconnected', () async {
      fakeNetworkInfo.connected = false;

      final result = await repository.signIn(
        const SignInRequest(
          email: 'test@example.com',
          password: 'password123',
        ),
      );

      expect(result, equals(const Left<Failure, Unit>(OfflineFailure())));
    });

    test(
      'should map InvalidEmailException to InvalidEmailFailure on signIn',
      () async {
        fakeDataSource.throwInvalidEmail = true;

        final result = await repository.signIn(
          const SignInRequest(
            email: 'invalid-email',
            password: 'password123',
          ),
        );

        expect(
          result,
          equals(const Left<Failure, Unit>(InvalidEmailFailure())),
        );
      },
    );

    test(
      'should map NotVerifiedException to NotVerifiedFailure on signIn',
      () async {
        fakeDataSource.throwNotVerified = true;

        final result = await repository.signIn(
          const SignInRequest(
            email: 'notverified@example.com',
            password: 'password123',
          ),
        );

        expect(result, equals(const Left<Failure, Unit>(NotVerifiedFailure())));
      },
    );

    test('should map RequiresRecentLoginException on deleteAccount', () async {
      fakeDataSource.throwRequiresRecentLogin = true;

      final result = await repository.deleteAccount();

      expect(
        result,
        equals(const Left<Failure, Unit>(RequiresRecentLoginFailure())),
      );
    });

    test('should map GoogleSignInCancelledException on signGoogle', () async {
      fakeDataSource.throwGoogleCancelled = true;

      final result = await repository.signGoogle();

      expect(
        result,
        equals(const Left<Failure, Unit>(GoogleSignInCancelledFailure())),
      );
    });

    test('should execute resetPassword successfully', () async {
      final result = await repository.resetPassword('user@example.com');

      expect(result, equals(const Right<Failure, Unit>(unit)));
    });

    test('should execute logout successfully', () async {
      final result = await repository.logout();

      expect(result, equals(const Right<Failure, Unit>(unit)));
    });
  });
}
