import 'dart:async';

import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({
    required this.currentUserId,
    required this.currentUserName,
    this.filterOnlineOnly = false,
    this.filterGroupsOnly = false,
    super.key,
  });

  final String currentUserId;
  final String currentUserName;
  final bool filterOnlineOnly;
  final bool filterGroupsOnly;

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes.clamp(1, 59)}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationsCubit, ConversationsState>(
      builder: (context, state) {
        if (state is ConversationsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state is ConversationsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.message,
                  style: const TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () => context.read<ConversationsCubit>().retry(),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        if (state is ConversationsEmpty) {
          return Center(
            child: Text(
              filterGroupsOnly
                  ? 'No groups yet.\nTap "Create New Group" to get started!'
                  : filterOnlineOnly
                  ? 'No friends currently online.'
                  : 'No conversations yet.\nTap the edit button below to start a chat!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15.sp,
              ),
            ),
          );
        }

        if (state is ConversationsLoaded) {
          var conversations = state.conversations;

          if (filterGroupsOnly) {
            conversations = conversations.where((c) => c.isGroup).toList();
          } else if (filterOnlineOnly) {
            conversations = conversations
                .where((c) => c.isOtherUserOnline(currentUserId))
                .toList();
          }

          if (conversations.isEmpty) {
            return Center(
              child: Text(
                filterGroupsOnly
                    ? 'No groups yet.'
                    : filterOnlineOnly
                    ? 'No friends currently online.'
                    : 'No conversations yet.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15.sp,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(
              color: Color(0xFF1C2530),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final name = conversation.getDisplayName(currentUserId);
              final avatar = conversation.getDisplayAvatar(currentUserId);
              final hasUnread = conversation.hasUnreadMessages(currentUserId);
              final isOnline = conversation.isOtherUserOnline(currentUserId);

              return ChatListItem(
                name: name,
                message:
                    conversation.lastMessage ??
                    (conversation.isGroup
                        ? 'Group created'
                        : 'Started a new chat'),
                time: _formatTime(conversation.lastMessageAt),
                avatarUrl: avatar,
                hasUnread: hasUnread,
                isOnline: isOnline,
                isGroup: conversation.isGroup,
                onTap: () {
                  unawaited(
                    context.push(
                      '/conversation',
                      extra: {
                        'conversation': conversation,
                        'currentUserId': currentUserId,
                        'currentUserName': currentUserName,
                      },
                    ),
                  );
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class ChatListItem extends StatelessWidget {
  const ChatListItem({
    required this.name,
    required this.message,
    required this.time,
    this.avatarUrl,
    this.hasUnread = false,
    this.isOnline = false,
    this.isGroup = false,
    this.onTap,
    super.key,
  });

  final String name;
  final String message;
  final String time;
  final String? avatarUrl;
  final bool hasUnread;
  final bool isOnline;
  final bool isGroup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
      leading: Stack(
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          if (isOnline && !isGroup)
            const Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 6,
                backgroundColor: Colors.greenAccent,
              ),
            ),
        ],
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread ? Colors.white70 : Colors.grey,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              color: hasUnread ? const Color(0xFF1E6AFF) : Colors.grey,
              fontSize: 12.sp,
            ),
          ),
          if (hasUnread) ...[
            SizedBox(height: 6.h),
            const CircleAvatar(
              radius: 5,
              backgroundColor: Color(0xFF1E6AFF),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
