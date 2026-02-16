import 'package:chat_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.bgStart, AppColors.bgEnd],
  );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Tajawal',
      colorSchemeSeed: Colors.blue,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Tajawal',
      colorSchemeSeed: Colors.blue,
    );
  }
}
