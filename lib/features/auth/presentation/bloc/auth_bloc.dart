import 'package:bloc/bloc.dart';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/delete_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_google_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this.signInUseCase,
    required this.deleteUseCase,
    required this.checkEmailVerifiedUseCase,
    required this.sendEmailVerificationUseCase,
    required this.signUpUseCase,
    required this.signGoogleUseCase,
    required this.logoutUseCase,
    required this.resetPasswordUseCase,
  }) : super(const AuthInitial()) {
    on<SignInEvent>((event, emit) async {
      emit(const AuthLoading());

      final result = await signInUseCase(event.request);

      result.fold(
        (failure) {
          if (failure is NotVerifiedFailure) {
            emit(const AuthNeedsEmailVerification());
          } else {
            emit(AuthError(message: mapFailureToMessage(failure)));
          }
        },
        (_) => emit(const AuthSuccess()),
      );
    });

    on<SignUpEvent>((event, emit) async {
      emit(const AuthLoading());

      final result = await signUpUseCase(event.request);

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(const SignUpSuccess()),
      );
    });

    on<SignByGoogleEvent>((event, emit) async {
      emit(const AuthLoading());
      final result = await signGoogleUseCase();

      result.fold(
        (failure) {
          if (failure is GoogleSignInCancelledFailure) {
            emit(const AuthInitial());
          } else {
            emit(AuthError(message: mapFailureToMessage(failure)));
          }
        },
        (_) => emit(const GoogleSuccess()),
      );
    });

    on<CheckVerifiedEvent>((event, emit) async {
      emit(const AuthLoading());

      final result = await checkEmailVerifiedUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(const VerifiedSuccess()),
      );
    });

    on<SendEmailVerificationEvent>((event, emit) async {
      emit(const AuthLoading());

      final result = await sendEmailVerificationUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(const VerificationEmailSentSuccess()),
      );
    });

    on<DeleteAccountEvent>((event, emit) async {
      emit(const DeleteLoading());

      final result = await deleteUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(const DeleteSuccess()),
      );
    });

    on<LogoutEvent>((event, emit) async {
      emit(const LogoutLoading());

      final result = await logoutUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(const LogoutSuccess()),
      );
    });

    on<ResetPasswordEvent>((event, emit) async {
      emit(const ResetPasswordLoading());

      final result = await resetPasswordUseCase(event.email);

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(const ResetPasswordSuccess()),
      );
    });
  }

  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignGoogleUseCase signGoogleUseCase;
  final CheckEmailVerifiedUseCase checkEmailVerifiedUseCase;
  final SendEmailVerificationUseCase sendEmailVerificationUseCase;
  final DeleteUseCase deleteUseCase;
  final LogoutUseCase logoutUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;

  String mapFailureToMessage(Failure failure) {
    if (failure is OfflineFailure) {
      return offlineError;
    } else if (failure is ServerFailure) {
      return serverErrorMessage;
    } else if (failure is NotVerifiedFailure) {
      return notVerifiedMessage;
    } else if (failure is SignInFailure ||
        failure is WrongPasswordFailure ||
        failure is UserNotFoundFailure) {
      return signInInvalidCredentials;
    } else if (failure is WeekPasswordFailure) {
      return signUpWeakPassword;
    } else if (failure is AlreadyRegisteredFailure) {
      return signUpEmailExists;
    } else if (failure is InvalidEmailFailure) {
      return invalidEmailMessage;
    } else if (failure is UserDisabledFailure) {
      return userDisabledMessage;
    } else if (failure is RequiresRecentLoginFailure) {
      return requiresRecentLoginMessage;
    } else if (failure is TooManyRequestsFailure) {
      return tooManyRequestsMessage;
    } else if (failure is GoogleSignInCancelledFailure) {
      return googleSignInCancelledMessage;
    } else if (failure is PermissionDeniedFailure) {
      return permissionDeniedMessage;
    } else {
      return unknownError;
    }
  }
}
