import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/core/theme/app_text_styles.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/core/widgets/snackbar_message.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/widgets/chat_icon.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_up_button.dart';
import 'package:chat_app/features/auth/presentation/widgets/verify_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  void _showErrorDialog(BuildContext context, String message) {
    unawaited(
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
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
          } else if (state is VerifiedSuccess) {
            context.go('/home');
          } else if (state is VerificationEmailSentSuccess) {
            SnackBarMessage().showSuccessSnackBar(
              message: emailVerificationSuccessMessage,
              context: context,
            );
          } else if (state is DeleteSuccess || state is LogoutSuccess) {
            context.go('/signIn');
          }
        },
        child: Container(
          width: 1.sw,
          height: 1.sh,
          decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackButton(
                        color: Colors.white,
                        onPressed: () {
                          context.go('/signIn');
                        },
                      ),
                      Text(
                        'Verify Email',
                        style: AppTextStyles.headPage.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                  SizedBox(height: 36.h),
                  const Center(child: ChatIcon()),
                  SizedBox(height: 28.h),
                  Center(
                    child: Text('Check your Email', style: AppTextStyles.title),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "We've sent a verification link to your email address. Please click the link in your email to verify your account, then click 'Check Verification'.",
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 36.h),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return Column(
                        children: [
                          SignUpButton(
                            onPressed: isLoading
                                ? () {}
                                : () {
                                    context.read<AuthBloc>().add(
                                      const CheckVerifiedEvent(),
                                    );
                                  },
                            name: isLoading
                                ? 'Checking...'
                                : 'Check Verification',
                          ),
                          SizedBox(height: 16.h),
                          VerifyButton(
                            onPressed: isLoading
                                ? () {}
                                : () {
                                    context.read<AuthBloc>().add(
                                      const SendEmailVerificationEvent(),
                                    );
                                  },
                            name: 'Resend Verification Link',
                            color: const Color(0xFF1E6AFF),
                          ),
                          SizedBox(height: 16.h),
                          VerifyButton(
                            onPressed: isLoading
                                ? () {}
                                : () {
                                    context.read<AuthBloc>().add(
                                      const LogoutEvent(),
                                    );
                                  },
                            name: 'Back to Sign In',
                            color: Colors.grey.shade700,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
