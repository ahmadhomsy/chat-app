import 'package:chat_app/core/theme/app_text_styles.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class VerifyButton extends StatelessWidget {

  const VerifyButton({
    required this.onPressed, required this.name, required this.color, super.key,
  });
  final VoidCallback onPressed;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 0,
            ),
            onPressed: (state is DeleteLoading) ? null : onPressed,
            child: (state is DeleteLoading)
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
