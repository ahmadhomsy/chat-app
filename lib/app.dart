import 'package:chat_app/core/helpers/go_router_helper.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'ChatApp',
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          routerConfig: router,
        );
      },
    );
  }
}
