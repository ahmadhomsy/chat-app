import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chat_app/core/constants/messages.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/theme/app_text_styles.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/core/widgets/snackbar_message.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/cubit/password_visibility_cubit.dart';
import 'package:chat_app/features/auth/presentation/widgets/input_field.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_up_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
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
      body: BlocProvider(
        create: (_) => PasswordVisibilityCubit(),
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              _showErrorDialog(state.message);
            } else if (state is ResetPasswordSuccess) {
              SnackBarMessage().showSuccessSnackBar(
                message: resetPasswordSuccessMessage,
                context: context,
              );
              unawaited(
                Future<void>.delayed(const Duration(seconds: 2)).then((_) {
                  if (context.mounted) {
                    context.go('/signIn');
                  }
                }),
              );
            }
          },
          child: Container(
            width: 1.sw,
            height: 1.sh,
            decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(height: 12.h),
                      BackButton(
                        color: Colors.white,
                        onPressed: () => context.pop(),
                      ),
                      SizedBox(height: 24.h),
                      Center(
                        child: Container(
                          width: 120.w,
                          height: 120.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.primaryButton.withValues(
                                alpha: 0.5,
                              ),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.lock_reset,
                              color: Colors.white,
                              size: 56.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),
                      Text(
                        'Forgot Password?',
                        style: AppTextStyles.title,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "Don't worry! Enter your email address and we will send you a password reset link.",
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 36.h),
                      InputField(
                        hint: 'name@example.com',
                        email: true,
                        icon: Icons.email_outlined,
                        obscure: false,
                        controller: _emailController,
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'صيغة البريد الإلكتروني غير صالحة';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 36.h),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is ResetPasswordLoading;
                          return SignUpButton(
                            name: isLoading ? 'Sending...' : 'Send Reset Link',
                            onPressed: isLoading
                                ? () {}
                                : () {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    context.read<AuthBloc>().add(
                                      ResetPasswordEvent(
                                        email: _emailController.text.trim(),
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
                      SizedBox(height: 32.h),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Remember your password? ',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.white70,
                              ),
                            ),
                            InkWell(
                              onTap: () => context.go('/signIn'),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: const Color(0xFF1E6AFF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
