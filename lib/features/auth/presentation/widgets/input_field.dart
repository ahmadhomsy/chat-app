import 'package:chat_app/features/auth/presentation/cubit/password_visibility_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InputField extends StatelessWidget {
  const InputField({
    required this.hint,
    required this.icon,
    required this.obscure,
    required this.textInputAction,
    required this.controller,
    super.key,
    this.name = false,
    this.email = false,
    this.suffix,
    this.validator,
  });
  final String hint;
  final IconData icon;
  final bool obscure;
  final bool? name;
  final bool? email;
  final IconData? suffix;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          SizedBox(width: 12.w),
          Expanded(
            child: BlocBuilder<PasswordVisibilityCubit, bool>(
              builder: (context, isObscure) {
                return TextFormField(
                  controller: controller,
                  obscureText: suffix != null ? isObscure : obscure,
                  textInputAction: textInputAction,
                  autofillHints: name ?? false
                      ? [AutofillHints.name]
                      : email ?? false
                      ? [AutofillHints.email]
                      : null,
                  validator: validator,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: suffix != null
                        ? IconButton(
                            icon: Icon(
                              isObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              context
                                  .read<PasswordVisibilityCubit>()
                                  .toggleVisibility();
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
