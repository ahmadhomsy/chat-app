import 'package:flutter/material.dart';

class PinnedChats extends StatelessWidget {
  const PinnedChats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PINNED',
            style: TextStyle(color: Colors.grey, letterSpacing: 1),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              PinnedAvatar(name: 'Alice', online: true),
              SizedBox(width: 16),
              PinnedAvatar(name: 'Mark'),
              SizedBox(width: 16),
              AddPinned(),
            ],
          ),
        ],
      ),
    );
  }
}

class PinnedAvatar extends StatelessWidget {

  const PinnedAvatar({required this.name, super.key, this.online = false});
  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            const CircleAvatar(radius: 28),
            if (online)
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(radius: 6, backgroundColor: Colors.green),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class AddPinned extends StatelessWidget {
  const AddPinned({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
          child: const Icon(Icons.add, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        const Text('Add New', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
