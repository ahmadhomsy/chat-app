import 'dart:async';

import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_cubit.dart';
import 'package:chat_app/features/home/presentation/cubit/tabs_cubit.dart';
import 'package:chat_app/features/home/presentation/widgets/bottom_nav.dart';
import 'package:chat_app/features/home/presentation/widgets/chat_list_item.dart';
import 'package:chat_app/features/home/presentation/widgets/create_new_group.dart';
import 'package:chat_app/features/home/presentation/widgets/pinned_chats.dart';
import 'package:chat_app/features/home/presentation/widgets/tabs_section.dart';
import 'package:chat_app/features/home/presentation/widgets/top_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  int _bottomNavIndex = 0;
  late final String _currentUserId;
  late final String _currentUserName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = user?.uid ?? '';
    _currentUserName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    if (_currentUserId.isNotEmpty) {
      context.read<ConversationsCubit>().loadConversations(_currentUserId);
    }
  }

  void _openUserDiscovery() {
    unawaited(
      context.push(
        '/userDiscovery',
        extra: {
          'currentUserId': _currentUserId,
          'currentUserName': _currentUserName,
        },
      ),
    );
  }

  void _openCreateGroup() {
    unawaited(
      context.push(
        '/createGroup',
        extra: {
          'currentUserId': _currentUserId,
          'currentUserName': _currentUserName,
        },
      ),
    );
  }

  void _showSettingsDialog() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF17212B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        builder: (modalContext) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    _currentUserName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                  ),
                  const Divider(color: Color(0xFF242F3D), height: 32),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.orangeAccent,
                    ),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      context.read<AuthBloc>().add(const LogoutEvent());
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _confirmDeleteAccount();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteAccount() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF17212B),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.read<AuthBloc>().add(const DeleteAccountEvent());
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is LogoutSuccess || state is DeleteSuccess) {
          context.go('/signIn');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1621),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF1E6AFF),
          onPressed: _openUserDiscovery,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: _bottomNavIndex,
          onTap: (index) {
            setState(() => _bottomNavIndex = index);
            if (index == 1) {
              _openUserDiscovery();
            } else if (index == 2) {
              _showSettingsDialog();
            }
          },
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopBar(onSearchTap: _openUserDiscovery),
              const TabsSection(),
              SizedBox(height: 8.h),
              Expanded(
                child: BlocBuilder<TabsCubit, int>(
                  builder: (context, activeIndex) {
                    if (activeIndex == 1) {
                      // Online Friends tab
                      return ChatsList(
                        currentUserId: _currentUserId,
                        currentUserName: _currentUserName,
                        filterOnlineOnly: true,
                      );
                    } else if (activeIndex == 2) {
                      // Groups tab
                      return Column(
                        children: [
                          CreateNewGroupTile(onTap: _openCreateGroup),
                          Expanded(
                            child: ChatsList(
                              currentUserId: _currentUserId,
                              currentUserName: _currentUserName,
                              filterGroupsOnly: true,
                            ),
                          ),
                        ],
                      );
                    }

                    // Default All Chats tab
                    return Column(
                      children: [
                        PinnedChats(
                          currentUserId: _currentUserId,
                          currentUserName: _currentUserName,
                        ),
                        Expanded(
                          child: ChatsList(
                            currentUserId: _currentUserId,
                            currentUserName: _currentUserName,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
