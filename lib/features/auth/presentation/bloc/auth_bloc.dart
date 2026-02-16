import 'package:bloc/bloc.dart';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/delete_usecase.dart';
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
  }) : super(AuthInitial()) {
    on<SignInEvent>((event, emit) async {
      emit(AuthLoading());

      final result = await signInUseCase(event.request);

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(AuthSuccess()),
      );
    });
    on<DeleteAccountEvent>((event, emit) async {
      emit(DeleteLoading());

      final result = await deleteUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(DeleteSuccess()),
      );
    });
    on<SignByGoogleEvent>((event, emit) async {
      final result = await signGoogleUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(GoogleSuccess()),
      );
    });
    on<SignUpEvent>((event, emit) async {
      emit(AuthLoading());

      final result = await signUpUseCase(event.request);

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(AuthSuccess()),
      );
    });
    on<CheckVerifiedEvent>((event, emit) async {
      emit(AuthLoading());

      final result = await checkEmailVerifiedUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(VerifiedSuccess()),
      );
    });
    on<SendEmailVerificationEvent>((event, emit) async {
      emit(AuthLoading());

      final result = await sendEmailVerificationUseCase();

      result.fold(
        (failure) => emit(AuthError(message: mapFailureToMessage(failure))),
        (_) => emit(AuthSuccess()),
      );
    });
  }
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignGoogleUseCase signGoogleUseCase;
  final CheckEmailVerifiedUseCase checkEmailVerifiedUseCase;
  final SendEmailVerificationUseCase sendEmailVerificationUseCase;
  final DeleteUseCase deleteUseCase;
  String mapFailureToMessage(Failure failure) {
    if (failure is OfflineFailure) {
      return offlineError;
    } else if (failure is ServerFailure) {
      return serverErrorMessage;
    } else if (failure is NotVerifiedFailure) {
      return notVerifiedMessage;
    } else if (failure is SignInFailure) {
      return signInInvalidCredentials;
    } else if (failure is WeekPasswordFailure) {
      return signUpWeakPassword;
    } else if (failure is AlreadyRegisteredFailure) {
      return signUpEmailExists;
    } else if (failure is UnExpectedFailure) {
      return unknownError;
    } else if (failure is TooManyRequestsFailure) {
      return tooManyRequestsMessage;
    } else {
      return unknownError;
    }
  }
}
