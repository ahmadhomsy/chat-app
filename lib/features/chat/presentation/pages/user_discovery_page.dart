import 'dart:async';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/domain/usecases/start_direct_conversation_usecase.dart';
import 'package:chat_app/features/chat/presentation/cubit/user_discovery_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/user_discovery_state.dart';
import 'package:chat_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class UserDiscoveryPage extends StatefulWidget {
  const UserDiscoveryPage({
    required this.currentUserId,
    required this.currentUserName,
    super.key,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<UserDiscoveryPage> createState() => _UserDiscoveryPageState();
}

class _UserDiscoveryPageState extends State<UserDiscoveryPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      context.read<UserDiscoveryCubit>().loadUsers(widget.currentUserId),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        context.read<UserDiscoveryCubit>().search(widget.currentUserId, query),
      );
    });
  }

  Future<void> _startChatWithUser(UserEntity otherUser) async {
    if (_isStartingChat) return;
    setState(() => _isStartingChat = true);

    final startChatUseCase = sl<StartDirectConversationUseCase>();
    final result = await startChatUseCase(
      currentUserId: widget.currentUserId,
      otherUser: otherUser,
    );

    if (!mounted) return;
    setState(() => _isStartingChat = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open chat. Please retry.')),
        );
      },
      (conversation) {
        unawaited(
          context.push(
            '/conversation',
            extra: {
              'conversation': conversation,
              'currentUserId': widget.currentUserId,
              'currentUserName': widget.currentUserName,
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17212B),
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Start a Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF17212B),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
            ),
            if (_isStartingChat)
              const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: Color(0xFF17212B),
              ),
            Expanded(
              child: BlocBuilder<UserDiscoveryCubit, UserDiscoveryState>(
                builder: (context, state) {
                  if (state is UserDiscoveryLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (state is UserDiscoveryError) {
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
                            onPressed: () {
                              unawaited(
                                context.read<UserDiscoveryCubit>().loadUsers(
                                  widget.currentUserId,
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

                  if (state is UserDiscoveryEmpty) {
                    return Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16.sp,
                        ),
                      ),
                    );
                  }

                  if (state is UserDiscoveryLoaded) {
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: state.users.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: Color(0xFF1C2530),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final user = state.users[index];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 6.h,
                            horizontal: 8.w,
                          ),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF1E6AFF),
                                backgroundImage: user.photoUrl != null
                                    ? NetworkImage(user.photoUrl!)
                                    : null,
                                child: user.photoUrl == null
                                    ? Text(
                                        user.name.isNotEmpty
                                            ? user.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              if (user.isOnline)
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
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            user.email,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.primary,
                          ),
                          onTap: () => _startChatWithUser(user),
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
