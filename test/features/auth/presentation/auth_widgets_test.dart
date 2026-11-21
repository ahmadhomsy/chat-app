import 'package:chat_app/features/auth/domain/usecases/check_email_verified_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/delete_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/send_email_verification_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_google_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:chat_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/pages/forgot_page.dart';
import 'package:chat_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_in_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_bloc_test.dart';

Widget createTestableWidget(Widget child, {AuthBloc? authBloc}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      home: authBloc != null
          ? BlocProvider<AuthBloc>.value(value: authBloc, child: child)
          : child,
    ),
  );
}

void main() {
  late AuthBloc authBloc;
  late FakeAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    authBloc = AuthBloc(
      signInUseCase: SignInUseCase(fakeRepo),
      signUpUseCase: SignUpUseCase(fakeRepo),
      signGoogleUseCase: SignGoogleUseCase(fakeRepo),
      checkEmailVerifiedUseCase: CheckEmailVerifiedUseCase(fakeRepo),
      sendEmailVerificationUseCase: SendEmailVerificationUseCase(fakeRepo),
      deleteUseCase: DeleteUseCase(fakeRepo),
      logoutUseCase: LogoutUseCase(fakeRepo),
      resetPasswordUseCase: ResetPasswordUseCase(fakeRepo),
    );
  });

  tearDown(() async {
    await authBloc.close();
  });

  group('Auth Widget Tests', () {
    testWidgets('SignInForm renders fields and validates empty inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestableWidget(
          const Scaffold(body: SignInForm()),
          authBloc: authBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('الرجاء إدخال الايميل'), findsOneWidget);
      expect(find.text('الرجاء إدخال كلمة السر'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders input and Send button', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestableWidget(
          const ForgotPasswordScreen(),
          authBloc: authBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.ensureVisible(find.text('Send Reset Link'));
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('الرجاء إدخال البريد الإلكتروني'), findsOneWidget);
    });

    testWidgets(
      'VerifyEmailScreen renders verification instructions and buttons',
      (tester) async {
        await tester.pumpWidget(
          createTestableWidget(
            const VerifyEmailScreen(),
            authBloc: authBloc,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verify Email'), findsOneWidget);
        expect(find.text('Check your Email'), findsOneWidget);
        expect(find.text('Check Verification'), findsOneWidget);
        expect(find.text('Resend Verification Link'), findsOneWidget);
        expect(find.text('Back to Sign In'), findsOneWidget);
      },
    );
  });
}
