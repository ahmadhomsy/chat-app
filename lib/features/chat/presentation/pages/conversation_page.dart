import 'dart:async';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_bloc.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_event.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    required this.conversation,
    required this.currentUserId,
    required this.currentUserName,
    super.key,
  });

  final ConversationEntity conversation;
  final String currentUserId;
  final String currentUserName;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    context.read<MessagesBloc>().add(
      LoadMessagesEvent(
        conversationId: widget.conversation.id,
        currentUserId: widget.currentUserId,
      ),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<MessagesBloc>().add(
        LoadOlderMessagesEvent(
          conversationId: widget.conversation.id,
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _isSending = true;
    _textController.clear();

    context.read<MessagesBloc>().add(
      SendMessageEvent(
        conversationId: widget.conversation.id,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        text: text,
      ),
    );

    // Debounce to prevent rapid double-tap submission
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.conversation.getDisplayName(widget.currentUserId);
    final avatar = widget.conversation.getDisplayAvatar(widget.currentUserId);
    final isOnline = widget.conversation.isOtherUserOnline(
      widget.currentUserId,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17212B),
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1E6AFF),
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.conversation.isGroup)
                    Text(
                      '${widget.conversation.participantIds.length} members',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    )
                  else if (isOnline)
                    Text(
                      'online',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.greenAccent,
                      ),
                    )
                  else
                    Text(
                      'offline',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<MessagesBloc, MessagesState>(
                builder: (context, state) {
                  if (state is MessagesLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E6AFF),
                      ),
                    );
                  }

                  if (state is MessagesError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            state.message,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          SizedBox(height: 16.h),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E6AFF),
                            ),
                            onPressed: () {
                              context.read<MessagesBloc>().add(
                                LoadMessagesEvent(
                                  conversationId: widget.conversation.id,
                                  currentUserId: widget.currentUserId,
                                ),
                              );
                            },
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is MessagesEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet.\nSend a message to start chatting!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15.sp,
                        ),
                      ),
                    );
                  }

                  if (state is MessagesLoaded) {
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      itemCount:
                          state.messages.length +
                          (state.isLoadingOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.messages.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1E6AFF),
                              ),
                            ),
                          );
                        }

                        final message = state.messages[index];
                        final isMine = message.isMine(widget.currentUserId);

                        return _buildMessageBubble(
                          message: message,
                          isMine: isMine,
                          isGroup: widget.conversation.isGroup,
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required MessageEntity message,
    required bool isMine,
    required bool isGroup,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF1E6AFF) : const Color(0xFF182533),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine && isGroup && message.senderName != null) ...[
              Text(
                message.senderName!,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5AB6E3),
                ),
              ),
              SizedBox(height: 4.h),
            ],
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 11.sp,
                color: isMine ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(
          top: BorderSide(color: Color(0xFF242F3D), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1621),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: _isSending ? Colors.grey : AppColors.primary,
            ),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
