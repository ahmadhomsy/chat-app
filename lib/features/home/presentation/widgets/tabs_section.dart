import 'package:chat_app/features/home/presentation/cubit/tabs_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TabsSection extends StatelessWidget {
  const TabsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TabsCubit, int>(
      builder: (context, activeIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _TabItem(
                title: 'All Friends',
                isActive: activeIndex == 0,
                onTap: () => context.read<TabsCubit>().changeTab(0),
              ),
              _TabItem(
                title: 'Online',
                isActive: activeIndex == 1,
                onTap: () => context.read<TabsCubit>().changeTab(1),
              ),
              _TabItem(
                title: 'Groups',
                isActive: activeIndex == 2,
                onTap: () => context.read<TabsCubit>().changeTab(2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {

  const _TabItem({
    required this.title,
    required this.onTap, this.isActive = false,
  });
  final String title;
  final bool isActive;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF1E6AFF) : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
