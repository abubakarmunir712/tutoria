// Saved tutor chats: the history list, reopening a chat with its messages, carrying on in the
// same conversation, and deleting one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/conversations.dart';
import 'package:tutoria/features/chat/chat_screen.dart';
import 'package:tutoria/features/chat/conversations_screen.dart';

import 'support/harness.dart';

ConversationSummary chat(String id, String title) => ConversationSummary(
  id: id,
  title: title,
  subject: 'Mathematics',
  grade: 'B4',
  messages: 4,
  lastMessageAt: DateTime.now(),
);

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('the history lists saved chats, newest first', (t) async {
    final api = FakeApi(me: studentMe)
      ..savedChats = [chat('c1', 'What is a fraction?'), chat('c2', 'Add 3/4')];
    await pumpApp(
      t,
      const ConversationsScreen(learnerId: 'l-ama', subject: 'Mathematics'),
      api: api,
      me: studentMe,
    );
    await settle(t);

    expect(find.text('What is a fraction?'), findsOneWidget);
    expect(find.text('Add 3/4'), findsOneWidget);
    expect(find.textContaining('2 questions'), findsNWidgets(2));
  });

  testWidgets('an empty history says how it fills up', (t) async {
    await pumpApp(
      t,
      const ConversationsScreen(learnerId: 'l-ama'),
      me: studentMe,
    );
    await settle(t);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('a chat can be deleted after confirming', (t) async {
    final api = FakeApi(me: studentMe)..savedChats = [chat('c1', 'Old chat')];
    await pumpApp(
      t,
      const ConversationsScreen(learnerId: 'l-ama'),
      api: api,
      me: studentMe,
    );
    await settle(t);

    await t.tap(find.byTooltip('Delete conversation'));
    await settle(t);
    await t.tap(find.text('Delete'));
    await settle(t);

    expect(api.deletedChats, ['c1']);
    expect(find.text('Old chat'), findsNothing);
  });

  testWidgets('reopening a chat shows its messages and carries on in it', (
    t,
  ) async {
    final api = FakeApi(me: studentMe)
      ..savedChats = [chat('c1', 'What is a fraction?')]
      ..savedMessages['c1'] = [
        SavedMessage(isUser: true, content: 'What is a fraction?'),
        SavedMessage(isUser: false, content: 'A fraction is part of a whole.'),
      ];
    await pumpApp(
      t,
      const ChatScreen(
        grade: 'B4',
        subject: 'Mathematics',
        learnerId: 'l-ama',
        conversationId: 'c1',
      ),
      api: api,
      me: studentMe,
    );
    await settle(t);

    expect(find.text('What is a fraction?'), findsOneWidget);
    expect(find.textContaining('part of a whole'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'And a half?');
    await t.tap(find.byIcon(Icons.send_rounded));
    await settle(t);

    expect(api.asked, ['And a half?']);
    expect(api.askedConversation, 'c1');
  });
}
