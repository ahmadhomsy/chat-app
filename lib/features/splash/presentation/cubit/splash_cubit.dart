import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logged_in_usecase.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
part 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  SplashCubit({
    required this.loggedInUseCase,
    required this.checkEmailVerifiedUseCase,
  }) : super(SplashInitial()) {
    unawaited(initializeApp());
  }

  final LoggedInUseCase loggedInUseCase;
  final CheckEmailVerifiedUseCase checkEmailVerifiedUseCase;

  Future<void> initializeApp() async {
    emit(SplashLoading());

    try {
      await Future<void>.delayed(const Duration(seconds: 2));

      final result = await loggedInUseCase();

      result.fold(
        _handleFailure,
        (isLoggedIn) => isLoggedIn
            ? emit(SplashAuthenticated())
            : emit(SplashUnauthenticated()),
      );
    } on Exception catch (_) {
      emit(SplashError(message: initializationErrorMessage));
    }
  }

  void _handleFailure(Failure failure) {
    if (failure is NotVerifiedFailure) {
      emit(VerifiedError());
    } else if (failure is OfflineFailure) {
      emit(SplashError(message: offlineError));
    } else if (failure is ServerFailure) {
      emit(SplashError(message: serverErrorMessage));
    } else {
      emit(SplashError(message: initializationErrorMessage));
    }
  }
}
