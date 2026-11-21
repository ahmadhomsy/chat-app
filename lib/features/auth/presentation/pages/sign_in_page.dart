import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chat_app/core/theme/app_text_styles.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/widgets/chat_icon.dart';
import 'package:chat_app/features/auth/presentation/widgets/divider.dart';
import 'package:chat_app/features/auth/presentation/widgets/google_button.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_in_form.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_up_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  void _showErrorDialog(BuildContext context, String message) {
    unawaited(
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.rightSlide,
        title: 'Error',
        desc: message,
        btnOkText: 'حسناً',
        btnOkColor: const Color(0xFFE53935),
        btnOkOnPress: () {},
      ).show(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showErrorDialog(context, state.message);
          } else if (state is AuthNeedsEmailVerification) {
            context.go('/VerifyEmailScreen');
          } else if (state is AuthSuccess || state is GoogleSuccess) {
            context.go('/home');
          }
        },
        child: Container(
          width: 1.sw,
          height: 1.sh,
          decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 48.h),
                  const ChatIcon(),
                  SizedBox(height: 24.h),
                  Text('Welcome Back', style: AppTextStyles.title),
                  SizedBox(height: 8.h),
                  Text(
                    'Please sign in to your account',
                    style: AppTextStyles.normal,
                  ),
                  SizedBox(height: 40.h),
                  const SignInForm(),
                  SizedBox(height: 24.h),
                  const DividerWidget(),
                  SizedBox(height: 24.h),
                  const GoogleButton(),
                  SizedBox(height: 32.h),
                  const SignUpLink(),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
