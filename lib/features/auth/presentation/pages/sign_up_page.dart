import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chat_app/core/theme/app_text_styles.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/widgets/chat_icon.dart';
import 'package:chat_app/features/auth/presentation/widgets/divider.dart';
import 'package:chat_app/features/auth/presentation/widgets/google_button.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_in_link.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_up_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            AwesomeDialog(
              context: context,
              dismissOnTouchOutside: false,
              dismissOnBackKeyPress: false,
              dialogType: DialogType.error,
              animType: AnimType.bottomSlide,
              title: 'Error',
              desc: state.message,
              btnOkText: 'اعادة المحاولة',
              btnOkColor: const Color(0xFFE53935),
              btnOkOnPress: () {},
            ).show();
          }
          if (state is AuthSuccess) {
            context.go('/VerifyEmailScreen');
          }
          if (state is GoogleSuccess) {
            context.go('/home');
          }
        },
        child: Container(
          width: 1.sw,
          height: 1.sh,
          decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
              child: Column(
                children: <Widget>[
                  const ChatIcon(),
                  SizedBox(height: 24.h),
                  Text('Create Account', style: AppTextStyles.title),
                  SizedBox(height: 8.h),
                  Text(
                    'Connect with friends instantly.',
                    style: AppTextStyles.normal,
                  ),
                  SizedBox(height: 40.h),
                  const SignUpForm(),
                  SizedBox(height: 24.h),
                  const DividerWidget(),
                  SizedBox(height: 24.h),
                  const GoogleButton(),
                  SizedBox(height: 40.h),
                  const SignInLink(),
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
