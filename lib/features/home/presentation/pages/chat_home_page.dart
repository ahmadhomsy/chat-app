import 'package:chat_app/features/home/presentation/cubit/tabs_cubit.dart';
import 'package:chat_app/features/home/presentation/widgets/bottom_nav.dart';
import 'package:chat_app/features/home/presentation/widgets/chat_list_item.dart';
import 'package:chat_app/features/home/presentation/widgets/create_new_group.dart';
import 'package:chat_app/features/home/presentation/widgets/pinned_chats.dart';
import 'package:chat_app/features/home/presentation/widgets/tabs_section.dart';
import 'package:chat_app/features/home/presentation/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatHomePage extends StatelessWidget {
  const ChatHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E6AFF),
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: const BottomNav(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TopBar(),
            const TabsSection(),
            BlocBuilder<TabsCubit, int>(
              builder: (context, activeIndex) {
                if (activeIndex == 1) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 200,
                      child: Expanded(child: ChatsList()),
                    ),
                  );
                } else if (activeIndex == 2) {
                  SizedBox(
                    height: 620.h,
                    child: Column(
                      children: [
                        CreateNewGroupTile(onTap: () {}),
                        const Expanded(child: ChatsList()),
                      ],
                    ),
                  );
                }
                return SizedBox(
                  height: 600.h,
                  child: const Column(
                    children: [
                      PinnedChats(),
                      Expanded(child: ChatsList()),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
