import 'dart:async';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/features/auth/domain/entities/user_entities.dart';
import 'package:chat_app/features/chat/presentation/cubit/create_group_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/create_group_state.dart';
import 'package:chat_app/features/chat/presentation/cubit/user_discovery_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/user_discovery_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({
    required this.currentUserId,
    required this.currentUserName,
    super.key,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(
      context.read<UserDiscoveryCubit>().loadUsers(widget.currentUserId),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateGroupCubit, CreateGroupState>(
      listener: (context, state) {
        if (state is CreateGroupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else if (state is CreateGroupSuccess) {
          context.pop();
          unawaited(
            context.push(
              '/conversation',
              extra: {
                'conversation': state.conversation,
                'currentUserId': widget.currentUserId,
                'currentUserName': widget.currentUserName,
              },
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is CreateGroupLoading;
        final selectedMembers = state is CreateGroupInitial
            ? state.selectedMembers
            : <UserEntity>[];

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
              'New Group',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        unawaited(
                          context.read<CreateGroupCubit>().createGroup(
                            currentUserId: widget.currentUserId,
                            groupName: _groupNameController.text,
                          ),
                        );
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'Create (${selectedMembers.length})',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  color: const Color(0xFF17212B),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(0xFF242F3D),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextField(
                          controller: _groupNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Enter group name...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                  child: Text(
                    'SELECT PARTICIPANTS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12.sp,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<UserDiscoveryCubit, UserDiscoveryState>(
                    builder: (context, userState) {
                      if (userState is UserDiscoveryLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (userState is UserDiscoveryLoaded) {
                        return ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: userState.users.length,
                          separatorBuilder: (_, _) => const Divider(
                            color: Color(0xFF1C2530),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final user = userState.users[index];
                            final isSelected = selectedMembers.any(
                              (m) => m.id == user.id,
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 4.h,
                                horizontal: 8.w,
                              ),
                              leading: CircleAvatar(
                                radius: 22,
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
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                onChanged: (_) {
                                  context.read<CreateGroupCubit>().toggleMember(
                                    user,
                                  );
                                },
                              ),
                              onTap: () {
                                context.read<CreateGroupCubit>().toggleMember(
                                  user,
                                );
                              },
                            );
                          },
                        );
                      }

                      return const Center(
                        child: Text(
                          'No users available',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
