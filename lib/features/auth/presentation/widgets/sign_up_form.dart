import 'package:chat_app/core/widgets/snackbar_message.dart';
import 'package:chat_app/features/auth/domain/params/sign_up_request.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/cubit/password_visibility_cubit.dart';
import 'package:chat_app/features/auth/presentation/widgets/input_field.dart';
import 'package:chat_app/features/auth/presentation/widgets/sign_up_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _userName.dispose();
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
              hint: 'your name',
              name: true,
              icon: Icons.person,
              obscure: false,
              controller: _userName,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'الرجاء إدخال اسم المستخدم';
                }
                if (v.length < 3) {
                  return 'الاسم يجب أن يحتوي 3 أحرف على الأقل';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            InputField(
              hint: 'name@example.com',
              email: true,
              icon: Icons.email_outlined,
              obscure: false,
              controller: _email,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال الايميل';
                if (v.length < 9) return 'الايميل غير صالح';
                return null;
              },
            ),
            SizedBox(height: 16.h),
            InputField(
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscure: true,
              controller: _password,
              textInputAction: TextInputAction.next,
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
            InputField(
              hint: 'Re-enter your password',
              icon: Icons.lock_outline,
              obscure: true,
              controller: _confirmPassword,
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
            SizedBox(height: 40.h),
            SignUpButton(
              name: 'Sign Up',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                if (_password.text != _confirmPassword.text) {
                  SnackBarMessage().showErrorSnackBar(
                    message: 'كلمتا المرور غير متطابقتين',
                    context: context,
                  );
                  return;
                }

                final request = SignUpRequest(
                  password: _password.text,
                  email: _email.text,
                  name: _userName.text,
                );
                context.read<AuthBloc>().add(SignUpEvent(request: request));
              },
            ),
            // InputField(
            //   hint: 'Enter your password',
            //   icon: Icons.lock_outline,
            //   obscure: true,
            //   suffix: Icons.visibility_off_outlined,
            // ),
            // SizedBox(height: 16.h),
            // InputField(
            //   hint: 'Re-enter your password',
            //   icon: Icons.lock_outline,
            //   obscure: true,
            //   suffix: Icons.visibility_off_outlined,
            // ),
          ],
        ),
      ),
    );
  }
}
