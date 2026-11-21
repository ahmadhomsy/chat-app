import 'package:chat_app/features/chat/domain/entities/conversation_entity.dart';
import 'package:chat_app/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/mark_as_read_usecase.dart';
import 'package:chat_app/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:chat_app/features/chat/presentation/bloc/messages_bloc.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_cubit.dart';
import 'package:chat_app/features/chat/presentation/cubit/conversations_state.dart';
import 'package:chat_app/features/chat/presentation/pages/conversation_page.dart';
import 'package:chat_app/features/home/presentation/cubit/tabs_cubit.dart';
import 'package:chat_app/features/home/presentation/widgets/chat_list_item.dart'
    as chat_widgets;
import 'package:chat_app/features/home/presentation/widgets/tabs_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversations_cubit_test.dart';
import 'messages_bloc_test.dart';

Widget createTestableWidget({
  required Widget child,
  ConversationsCubit? convCubit,
  MessagesBloc? messagesBloc,
  TabsCubit? tabsCubit,
}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      home: MultiBlocProvider(
        providers: [
          if (convCubit != null)
            BlocProvider<ConversationsCubit>.value(value: convCubit),
          if (messagesBloc != null)
            BlocProvider<MessagesBloc>.value(value: messagesBloc),
          if (tabsCubit != null)
            BlocProvider<TabsCubit>.value(value: tabsCubit),
        ],
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('Chat & Home Widget Tests', () {
    testWidgets('TabsSection switches active tabs correctly', (tester) async {
      final tabsCubit = TabsCubit();

      await tester.pumpWidget(
        createTestableWidget(
          child: const TabsSection(),
          tabsCubit: tabsCubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Friends'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);

      await tester.tap(find.text('Online'));
      await tester.pumpAndSettle();
      expect(tabsCubit.state, equals(1));

      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(tabsCubit.state, equals(2));

      await tabsCubit.close();
    });

    testWidgets(
      'ChatsList renders empty state when state is ConversationsEmpty',
      (tester) async {
        final fakeRepo = FakeChatRepository();
        final convCubit = ConversationsCubit(
          getConversationsUseCase: GetConversationsUseCase(fakeRepo),
        )..emit(ConversationsEmpty());

        await tester.pumpWidget(
          createTestableWidget(
            child: const chat_widgets.ChatsList(
              currentUserId: 'u1',
              currentUserName: 'User 1',
            ),
            convCubit: convCubit,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('No conversations yet'), findsOneWidget);

        await convCubit.close();
      },
    );

    testWidgets(
      'ConversationPage displays header, message bubbles, and sends message',
      (tester) async {
        final fakeRepo = FakeMessagesChatRepository();
        final messagesBloc = MessagesBloc(
          getMessagesUseCase: GetMessagesUseCase(fakeRepo),
          sendMessageUseCase: SendMessageUseCase(fakeRepo),
          markAsReadUseCase: MarkAsReadUseCase(fakeRepo),
          chatRepository: fakeRepo,
        );

        final conversation = ConversationEntity(
          id: 'c1',
          type: 'direct',
          participantIds: const ['u1', 'u2'],
          createdBy: 'u1',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestableWidget(
            child: ConversationPage(
              conversation: conversation,
              currentUserId: 'u1',
              currentUserName: 'User One',
            ),
            messagesBloc: messagesBloc,
          ),
        );
        await tester.pump();

        // Emit empty messages to finish loading
        fakeRepo.messagesController.add(const []);
        await tester.pump();

        expect(find.text('Direct Chat'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);

        // Send a test message
        await tester.enterText(find.byType(TextField), 'Testing message');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump(const Duration(milliseconds: 350));

        expect(fakeRepo.sendMessageCalled, isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });
}
