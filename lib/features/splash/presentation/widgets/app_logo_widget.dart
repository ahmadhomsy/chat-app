import 'package:chat_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90.w,
      height: 90.w,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 42.sp),
    );
  }
}
