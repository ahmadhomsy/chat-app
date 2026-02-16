import 'package:chat_app/core/helpers/bloc_obs.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/features/auth/data/data_sources/firebase_auth_data_source.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/delete_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logged_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_google_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/splash/presentation/cubit/splash_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:logger/logger.dart';

final GetIt sl = GetIt.instance;
Future<void> init() async {
  sl
    ..registerFactory(
      () => AuthBloc(
        signInUseCase: sl(),
        signUpUseCase: sl(),
        signGoogleUseCase: sl(),
        checkEmailVerifiedUseCase: sl(),
        sendEmailVerificationUseCase: sl(),
        deleteUseCase: sl(),
      ),
    )
    ..registerFactory<SplashCubit>(
      () => SplashCubit(loggedInUseCase: sl(), checkEmailVerifiedUseCase: sl()),
    )
    ..registerLazySingleton<LoggedInUseCase>(() => LoggedInUseCase(sl()))
    ..registerLazySingleton<SignInUseCase>(() => SignInUseCase(sl()))
    ..registerLazySingleton<SignUpUseCase>(() => SignUpUseCase(sl()))
    ..registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(sl()))
    ..registerLazySingleton<SignGoogleUseCase>(() => SignGoogleUseCase(sl()))
    ..registerLazySingleton<DeleteUseCase>(() => DeleteUseCase(sl()))
    ..registerLazySingleton<SendEmailVerificationUseCase>(
      () => SendEmailVerificationUseCase(sl()),
    )
    ..registerLazySingleton<CheckEmailVerifiedUseCase>(
      () => CheckEmailVerifiedUseCase(sl()),
    )
    ..registerLazySingleton<AuthRepositories>(
      () => AuthRepositoryImpl(data: sl(), networkInfo: sl()),
    )
    ..registerLazySingleton<FirebaseAuthDataSource>(
      () => FirebaseAuthDataSourceImpl(
        firebaseAuth: sl(),
        firestore: sl(),
        googleSignIn: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()))
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)
    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)
    ..registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance)
    // sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn());
    // sl.registerLazySingleton<FlutterSecureStorage>(
    //         () => const FlutterSecureStorage());
    // sl.registerLazySingleton(() => http.Client());
    ..registerLazySingleton(InternetConnectionChecker.new)
    ..registerLazySingleton<Logger>(Logger.new)
    ..registerLazySingleton<MyBlocObserver>(
      () => MyBlocObserver(sl()),
    );
}
