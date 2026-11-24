import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/features/splash/presentation/cubit/splash_cubit.dart';
import 'package:chat_app/features/splash/presentation/widgets/app_logo_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final scaleCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    final fadeCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1).animate(scaleCurve);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(fadeCurve);
    unawaited(_controller.forward());

    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await context.read<SplashCubit>().initializeApp();
  }

  void _handleNavigation(SplashState state) {
    if (!mounted) return;

    if (state is VerifiedError) {
      context.go('/VerifyEmailScreen');
    } else if (state is SplashUnauthenticated) {
      context.go('/signIn');
    } else if (state is SplashAuthenticated) {
      context.go('/home');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;

    await AwesomeDialog(
      context: context,
      dismissOnTouchOutside: false,
      dismissOnBackKeyPress: false,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: 'Error',
      desc: message,
      btnOkText: 'Retry',
      btnOkColor: const Color(0xFFE53935),
      btnOkOnPress: () {
        unawaited(context.read<SplashCubit>().initializeApp());
      },
    ).show();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<SplashCubit, SplashState>(
        listener: (context, state) {
          if (state is SplashError) {
            unawaited(_showErrorDialog(state.message));
          } else {
            _handleNavigation(state);
          }
        },
        child: Container(
          width: 1.sw,
          height: 1.sh,
          decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: const AppLogo(),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'ChatApp',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Simple. Friendly. Chat.',
                  style: TextStyle(fontSize: 16.sp, color: Colors.white70),
                ),
                const Spacer(flex: 4),
                Text(
                  'V1.0.0',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white38),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
