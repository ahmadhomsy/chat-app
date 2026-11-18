import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/delete_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_google_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepositories {
  Either<Failure, Unit> signInResult = const Right(unit);
  Either<Failure, Unit> signUpResult = const Right(unit);
  Either<Failure, Unit> signGoogleResult = const Right(unit);
  Either<Failure, Unit> resetPasswordResult = const Right(unit);
  Either<Failure, Unit> logoutResult = const Right(unit);
  Either<Failure, Unit> deleteAccountResult = const Right(unit);
  Either<Failure, Unit> checkEmailVerifiedResult = const Right(unit);
  Either<Failure, Unit> sendEmailVerificationResult = const Right(unit);
  Either<Failure, bool> loggedInResult = const Right(true);

  @override
  Future<Either<Failure, Unit>> signIn(SignInRequest request) async =>
      signInResult;

  @override
  Future<Either<Failure, Unit>> signUp(SignUpRequest request) async =>
      signUpResult;

  @override
  Future<Either<Failure, Unit>> signGoogle() async => signGoogleResult;

  @override
  Future<Either<Failure, Unit>> resetPassword(String email) async =>
      resetPasswordResult;

  @override
  Future<Either<Failure, Unit>> logout() async => logoutResult;

  @override
  Future<Either<Failure, Unit>> deleteAccount() async => deleteAccountResult;

  @override
  Future<Either<Failure, Unit>> checkEmailVerified() async =>
      checkEmailVerifiedResult;

  @override
  Future<Either<Failure, Unit>> sendEmailVerification() async =>
      sendEmailVerificationResult;

  @override
  Future<Either<Failure, bool>> loggedIn() async => loggedInResult;
}

void main() {
  late AuthBloc authBloc;
  late FakeAuthRepository fakeRepository;

  setUp(() {
    fakeRepository = FakeAuthRepository();
    authBloc = AuthBloc(
      signInUseCase: SignInUseCase(fakeRepository),
      signUpUseCase: SignUpUseCase(fakeRepository),
      signGoogleUseCase: SignGoogleUseCase(fakeRepository),
      checkEmailVerifiedUseCase: CheckEmailVerifiedUseCase(fakeRepository),
      sendEmailVerificationUseCase: SendEmailVerificationUseCase(
        fakeRepository,
      ),
      deleteUseCase: DeleteUseCase(fakeRepository),
      logoutUseCase: LogoutUseCase(fakeRepository),
      resetPasswordUseCase: ResetPasswordUseCase(fakeRepository),
    );
  });

  tearDown(() async {
    await authBloc.close();
  });

  group('AuthBloc Tests', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, equals(const AuthInitial()));
    });

    test('SignInEvent emits [AuthLoading, AuthSuccess] on success', () async {
      const expectedStates = [
        AuthLoading(),
        AuthSuccess(),
      ];

      final expectation = expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(
        const SignInEvent(
          request: SignInRequest(
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );

      await expectation;
    });

    test(
      'SignInEvent emits [AuthLoading, AuthNeedsEmailVerification] when NotVerifiedFailure',
      () async {
        fakeRepository.signInResult = const Left<Failure, Unit>(
          NotVerifiedFailure(),
        );

        const expectedStates = [
          AuthLoading(),
          AuthNeedsEmailVerification(),
        ];

        final expectation = expectLater(
          authBloc.stream,
          emitsInOrder(expectedStates),
        );

        authBloc.add(
          const SignInEvent(
            request: SignInRequest(
              email: 'test@example.com',
              password: 'password123',
            ),
          ),
        );

        await expectation;
      },
    );

    test('SignUpEvent emits [AuthLoading, SignUpSuccess] on success', () async {
      const expectedStates = [
        AuthLoading(),
        SignUpSuccess(),
      ];

      final expectation = expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(
        const SignUpEvent(
          request: SignUpRequest(
            name: 'Ahmad',
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );

      await expectation;
    });

    test(
      'SignByGoogleEvent emits [AuthLoading, AuthInitial] when cancelled',
      () async {
        fakeRepository.signGoogleResult = const Left<Failure, Unit>(
          GoogleSignInCancelledFailure(),
        );

        const expectedStates = [
          AuthLoading(),
          AuthInitial(),
        ];

        final expectation = expectLater(
          authBloc.stream,
          emitsInOrder(expectedStates),
        );

        authBloc.add(const SignByGoogleEvent());

        await expectation;
      },
    );

    test(
      'ResetPasswordEvent emits [ResetPasswordLoading, ResetPasswordSuccess]',
      () async {
        const expectedStates = [
          ResetPasswordLoading(),
          ResetPasswordSuccess(),
        ];

        final expectation = expectLater(
          authBloc.stream,
          emitsInOrder(expectedStates),
        );

        authBloc.add(const ResetPasswordEvent(email: 'user@example.com'));

        await expectation;
      },
    );

    test('LogoutEvent emits [LogoutLoading, LogoutSuccess]', () async {
      const expectedStates = [
        LogoutLoading(),
        LogoutSuccess(),
      ];

      final expectation = expectLater(
        authBloc.stream,
        emitsInOrder(expectedStates),
      );

      authBloc.add(const LogoutEvent());

      await expectation;
    });
  });
}
