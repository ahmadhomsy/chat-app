import 'package:flutter/material.dart';

class CreateNewGroupTile extends StatelessWidget {
  const CreateNewGroupTile({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1621), // خلفية داكنة
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Circle Icon
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF102A56), // أزرق غامق
              ),
              child: const Icon(
                Icons.group_add,
                color: Color(0xFF1E6AFF),
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Text
            const Text(
              'Create New Group',
              style: TextStyle(
                color: Color(0xFF1E6AFF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
