import 'package:flutter/material.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ChatListItem(
          name: 'Alice Johnson',
          message: 'Hey! Are we still on for lunch?',
          time: '2m',
          unread: 2,
        ),
        ChatListItem(name: 'Mark Smith', message: 'Sent an image', time: '15m'),
        ChatListItem(
          name: 'Sarah Lee',
          message: 'Call me when you can.',
          time: '1h',
        ),
      ],
    );
  }
}

class ChatListItem extends StatelessWidget {

  const ChatListItem({
    required this.name, required this.message, required this.time, super.key,
    this.unread = 0,
  });
  final String name;
  final String message;
  final String time;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(radius: 26),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: Text(message, style: const TextStyle(color: Colors.grey)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time, style: const TextStyle(color: Colors.grey)),
          if (unread > 0)
            CircleAvatar(
              radius: 10,
              backgroundColor: const Color(0xFF1E6AFF),
              child: Text('$unread', style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
