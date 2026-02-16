import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0E1621),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedItemColor: const Color(0xFF1E6AFF),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
        // BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'People'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
