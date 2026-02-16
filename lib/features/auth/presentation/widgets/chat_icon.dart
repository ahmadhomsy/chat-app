import 'package:chat_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatIcon extends StatelessWidget {
  const ChatIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72.w,
      height: 72.w,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Icon(
        Icons.chat_bubble_outline,
        color: AppColors.primary,
        size: 32.sp,
      ),
    );
  }
}
