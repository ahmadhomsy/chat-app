import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    this.onSearchTap,
    super.key,
  });

  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ChatUp',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: onSearchTap,
            icon: CircleAvatar(
              backgroundColor: const Color(0xFF1C2530),
              child: Icon(
                Icons.search,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
