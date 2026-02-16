import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/theme/app_text_styles.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignUpButton extends StatelessWidget {

  const SignUpButton({required this.onPressed, required this.name, super.key});
  final VoidCallback onPressed;
  final String name;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 0,
            ),
            onPressed: (state is AuthLoading) ? null : onPressed,
            child: (state is AuthLoading)
                ? const Center(
                    child: CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 15,
                    ),
                  )
                : Text(name, style: AppTextStyles.button),
          ),
        );
      },
    );
  }
}
