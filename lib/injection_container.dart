import 'package:chat_app/core/helpers/bloc_obs.dart';
import 'package:chat_app/core/helpers/network_info.dart';
import 'package:chat_app/core/services/notification_service.dart';
import 'package:chat_app/core/services/presence_service.dart';
import 'package:chat_app/features/auth/data/data_sources/firebase_auth_data_source.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repositories.dart';
import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/delete_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logged_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_google_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/chat/data/data_sources/chat_remote_data_source.dart';
import 'package:chat_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chat/domain/usecases/create_group_conversation_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/get_all_users_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/mark_as_read_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/search_users_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/start_direct_conversation_usecase.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_bloc.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/create_group_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/user_discovery_cubit.dart';
import 'package:chat_app/features/splash/presentation/cubit/splash_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:logger/logger.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  sl
    // Features - Auth BLoC
    ..registerFactory(
      () => AuthBloc(
        signInUseCase: sl(),
        signUpUseCase: sl(),
        signGoogleUseCase: sl(),
        checkEmailVerifiedUseCase: sl(),
        sendEmailVerificationUseCase: sl(),
        deleteUseCase: sl(),
        logoutUseCase: sl(),
        resetPasswordUseCase: sl(),
      ),
    )
    // Features - Splash Cubit
    ..registerFactory<SplashCubit>(
      () => SplashCubit(
        loggedInUseCase: sl(),
        checkEmailVerifiedUseCase: sl(),
      ),
    )
    // Features - Chat Blocs & Cubits
    ..registerFactory(
      () => ConversationsCubit(
        getConversationsUseCase: sl(),
      ),
    )
    ..registerFactory(
      () => MessagesBloc(
        getMessagesUseCase: sl(),
        sendMessageUseCase: sl(),
        markAsReadUseCase: sl(),
        chatRepository: sl(),
      ),
    )
    ..registerFactory(
      () => UserDiscoveryCubit(
        getAllUsersUseCase: sl(),
        searchUsersUseCase: sl(),
      ),
    )
    ..registerFactory(
      () => CreateGroupCubit(
        createGroupConversationUseCase: sl(),
      ),
    )
    // Use cases - Auth
    ..registerLazySingleton<LoggedInUseCase>(() => LoggedInUseCase(sl()))
    ..registerLazySingleton<SignInUseCase>(() => SignInUseCase(sl()))
    ..registerLazySingleton<SignUpUseCase>(() => SignUpUseCase(sl()))
    ..registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(sl()))
    ..registerLazySingleton<ResetPasswordUseCase>(
      () => ResetPasswordUseCase(sl()),
    )
    ..registerLazySingleton<SignGoogleUseCase>(() => SignGoogleUseCase(sl()))
    ..registerLazySingleton<DeleteUseCase>(() => DeleteUseCase(sl()))
    ..registerLazySingleton<SendEmailVerificationUseCase>(
      () => SendEmailVerificationUseCase(sl()),
    )
    ..registerLazySingleton<CheckEmailVerifiedUseCase>(
      () => CheckEmailVerifiedUseCase(sl()),
    )
    // Use cases - Chat
    ..registerLazySingleton<GetConversationsUseCase>(
      () => GetConversationsUseCase(sl()),
    )
    ..registerLazySingleton<GetMessagesUseCase>(
      () => GetMessagesUseCase(sl()),
    )
    ..registerLazySingleton<SendMessageUseCase>(
      () => SendMessageUseCase(sl()),
    )
    ..registerLazySingleton<StartDirectConversationUseCase>(
      () => StartDirectConversationUseCase(sl()),
    )
    ..registerLazySingleton<CreateGroupConversationUseCase>(
      () => CreateGroupConversationUseCase(sl()),
    )
    ..registerLazySingleton<MarkAsReadUseCase>(
      () => MarkAsReadUseCase(sl()),
    )
    ..registerLazySingleton<SearchUsersUseCase>(
      () => SearchUsersUseCase(sl()),
    )
    ..registerLazySingleton<GetAllUsersUseCase>(
      () => GetAllUsersUseCase(sl()),
    )
    // Repositories
    ..registerLazySingleton<AuthRepositories>(
      () => AuthRepositoryImpl(data: sl(), networkInfo: sl()),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
    )
    // Data Sources
    ..registerLazySingleton<FirebaseAuthDataSource>(
      () => FirebaseAuthDataSourceImpl(
        firebaseAuth: sl(),
        firestore: sl(),
        googleSignIn: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(firestore: sl()),
    )
    // Core & Services
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()))
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)
    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)
    ..registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance)
    ..registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance)
    ..registerLazySingleton<PresenceService>(
      () => PresenceService(firestore: sl(), firebaseAuth: sl()),
    )
    ..registerLazySingleton<NotificationService>(
      () => NotificationService(messaging: sl(), firestore: sl(), auth: sl()),
    )
    ..registerLazySingleton(InternetConnectionChecker.new)
    ..registerLazySingleton<Logger>(Logger.new)
    ..registerLazySingleton<MyBlocObserver>(
      () => MyBlocObserver(sl()),
    );
}
