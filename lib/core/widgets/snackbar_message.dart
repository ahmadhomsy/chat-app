import 'package:flutter/material.dart';

class SnackBarMessage {
  void showSuccessSnackBar({
    required String message,
    required BuildContext context,
  }) {
    _showCustomSnackBar(
      context: context,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: Colors.green.shade600,
    );
  }

  void showErrorSnackBar({
    required String message,
    required BuildContext context,
  }) {
    _showCustomSnackBar(
      context: context,
      message: message,
      icon: Icons.error,
      backgroundColor: Colors.red.shade400,
    );
  }

  void _showCustomSnackBar({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.6),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
