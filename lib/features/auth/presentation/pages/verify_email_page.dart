import 'package:awesome_dialog/awesome_dialog.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.bottomSlide,
              title: 'Error',
              desc: state.message,
              btnOkText: 'اعادة الارسال',
              btnOkColor: const Color(0xFFE53935),
              btnOkOnPress: () {
                context.read<AuthBloc>().add(SendEmailVerificationEvent());
              },
            ).show();
          }
          if (state is VerifiedSuccess) {
            context.go('/home');
          }
          if (state is AuthSuccess) {
            SnackBarMessage().showSuccessSnackBar(
              message: 'تم الارسال بنجاح',
              context: context,
            );
          }
          if (state is DeleteSuccess) {
            context.go('/signUp');
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
                        color: Colors.black,
                        onPressed: () {
                          context.go('/signUp');
                        },
                      ),
                      Text('Verify Email', style: AppTextStyles.headPage),
                      SizedBox(width: 48.w),
                    ],
                  ),
                  SizedBox(height: 48.h),
                  const Center(child: ChatIcon()),
                  SizedBox(height: 32.h),
                  Center(
                    child: Text('Check your Gmail', style: AppTextStyles.title),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "We've sent a 6-digit code to your email. Please enter it.",
                    style: AppTextStyles.shade,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40.h),
                  SignUpButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(CheckVerifiedEvent());
                    },
                    name: 'Verify Email',
                  ),
                  SizedBox(height: 16.h),
                  VerifyButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(DeleteAccountEvent());
                    },
                    name: 'تراجع عن انشاء الحساب',
                    color: Colors.red,
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
