import 'package:flutter/material.dart';

class SignFieldWidget extends StatelessWidget {

  const SignFieldWidget({
    required this.controller, required this.label, super.key,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final focusedBorderColor = isDark
        ? Colors.blueAccent.shade100
        : Colors.blueAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        textInputAction: textInputAction,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        validator:
            validator ??
            (val) {
              if (val == null || val.trim().isEmpty) {
                return '$label لا يمكن أن يكون فارغًا';
              }
              return null;
            },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
