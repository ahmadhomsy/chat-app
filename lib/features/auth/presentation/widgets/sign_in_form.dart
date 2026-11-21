import 'dart:async';

import 'package:chat_app/features/auth/domain/params/sign_in_request.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/cubit/password_visibility_cubit.dart';
import 'package:chat_app/features/auth/presentation/widgets/input_field.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_up_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PasswordVisibilityCubit(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            InputField(
              hint: 'name@example.com',
              email: true,
              icon: Icons.email_outlined,
              obscure: false,
              controller: _email,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'الرجاء إدخال الايميل';
                }
                if (!v.contains('@') || !v.contains('.')) {
                  return 'الايميل غير صالح';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            InputField(
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscure: true,
              controller: _password,
              textInputAction: TextInputAction.done,
              suffix: Icons.visibility_off_outlined,
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال كلمة السر';
                if (v.length < 6) {
                  return 'كلمة السر يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  unawaited(context.push('/ForgotPasswordScreen'));
                },
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            SizedBox(height: 35.h),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final isLoading = state is AuthLoading;
                return SignUpButton(
                  name: isLoading ? 'Signing In...' : 'Sign In',
                  onPressed: isLoading
                      ? () {}
                      : () {
                          if (!_formKey.currentState!.validate()) return;
                          final request = SignInRequest(
                            password: _password.text,
                            email: _email.text.trim(),
                          );
                          context.read<AuthBloc>().add(
                            SignInEvent(request: request),
                          );
                        },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
