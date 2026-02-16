part of 'splash_cubit.dart';

@immutable
sealed class SplashState extends Equatable {
  @override
  List<Object?> get props => [];
}

final class SplashInitial extends SplashState {}

final class SplashLoading extends SplashState {}

final class SplashAuthenticated extends SplashState {}

final class SplashUnauthenticated extends SplashState {}

final class SplashError extends SplashState {
  SplashError({required this.message});
  final String message;
  @override
  List<Object> get props => [message];
}

final class VerifiedError extends SplashState {}
