import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTextStyles {
  static TextStyle headline = TextStyle(
    color: const Color(0xFF0E3647),
    fontWeight: FontWeight.w700,
    fontSize: 30.sp,
  );

  static TextStyle title = TextStyle(
    fontSize: 32.sp,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle normal = TextStyle(fontSize: 16.sp, color: Colors.white70);
  static TextStyle button = TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static TextStyle headPage = TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w600,
    // color: AppColors.darkText,
  );
  static TextStyle shade = TextStyle(
    fontSize: 16.sp,
    color: Colors.grey.shade600,
  );
  // static TextStyle boldBody = TextStyle(
  //   fontSize: 18.sp,
  //   fontWeight: FontWeight.bold,
  //   color: AppColors.white,
  // );
}
