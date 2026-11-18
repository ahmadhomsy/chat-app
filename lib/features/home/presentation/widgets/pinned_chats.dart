import 'dart:async';

import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class PinnedChats extends StatelessWidget {
  const PinnedChats({
    required this.currentUserId,
    required this.currentUserName,
    super.key,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationsCubit, ConversationsState>(
      builder: (context, state) {
        final conversations = state is ConversationsLoaded
            ? state.conversations.take(5).toList()
            : <ConversationEntity>[];

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECENT CHATS',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12.sp,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 80.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AddPinned(
                      onTap: () {
                        unawaited(
                          context.push(
                            '/userDiscovery',
                            extra: {
                              'currentUserId': currentUserId,
                              'currentUserName': currentUserName,
                            },
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 16.w),
                    ...conversations.map((c) {
                      final name = c.getDisplayName(currentUserId);
                      final avatar = c.getDisplayAvatar(currentUserId);
                      final isOnline = c.isOtherUserOnline(currentUserId);

                      return Padding(
                        padding: EdgeInsets.only(right: 16.w),
                        child: PinnedAvatar(
                          name: name,
                          avatarUrl: avatar,
                          online: isOnline,
                          onTap: () {
                            unawaited(
                              context.push(
                                '/conversation',
                                extra: {
                                  'conversation': c,
                                  'currentUserId': currentUserId,
                                  'currentUserName': currentUserName,
                                },
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PinnedAvatar extends StatelessWidget {
  const PinnedAvatar({
    required this.name,
    this.avatarUrl,
    this.online = false,
    this.onTap,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1E6AFF),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (online)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: Colors.greenAccent,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          SizedBox(
            width: 60.w,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class AddPinned extends StatelessWidget {
  const AddPinned({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade700, width: 1.5),
            ),
            child: const Icon(Icons.add, color: Colors.white70),
          ),
          SizedBox(height: 6.h),
          Text(
            'New Chat',
            style: TextStyle(color: Colors.grey, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}
