import 'package:chat_app/core/helpers/page_transitions.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/pages/forgot_page.dart';
import 'package:chat_app/features/auth/presentation/pages/sign_in_page.dart';
import 'package:chat_app/features/auth/presentation/pages/sign_up_page.dart';
import 'package:chat_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:chat_app/features/home/presentation/cubit/tabs_cubit.dart';
import 'package:chat_app/features/home/presentation/pages/chat_home_page.dart';
import 'package:chat_app/features/splash/presentation/cubit/splash_cubit.dart';
import 'package:chat_app/features/splash/presentation/pages/splash_page.dart';
import 'package:chat_app/injection_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (context) => sl<SplashCubit>(),
          child: const SplashScreen(),
        ),
        transitionsBuilder: PageTransitions.fadeTransition,
      ),
    ),
    GoRoute(
      path: '/signIn',
      name: 'signIn',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (context) => sl<AuthBloc>(),
          child: const SignInPage(),
        ),
        transitionsBuilder: PageTransitions.fadeTransition,
      ),
    ),
    GoRoute(
      path: '/signUp',
      name: 'signUp',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const SignUpPage(),
          ),
          transitionsBuilder: PageTransitions.fadeTransition,
        );
      },
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (context) => TabsCubit(),
          child: const ChatHomePage(),
        ),
        transitionsBuilder: PageTransitions.fadeTransition,
      ),
    ),
    GoRoute(
      path: '/VerifyEmailScreen',
      name: 'VerifyEmailScreen',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (context) => sl<AuthBloc>(),
          child: const VerifyEmailScreen(),
        ),
        transitionsBuilder: PageTransitions.slideFromLeft,
      ),
    ),
    GoRoute(
      path: '/ForgotPasswordScreen',
      name: 'ForgotPasswordScreen',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ForgotPasswordScreen(),
        transitionsBuilder: PageTransitions.slideFromLeft,
      ),
    ),
  ],
);
