import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/features/splash/presentation/widgets/app_logo_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App theme and logo smoke test', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: AppLogo(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLogo), findsOneWidget);
  });
}
