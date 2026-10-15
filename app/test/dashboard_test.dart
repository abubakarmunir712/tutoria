// What the dashboard's buttons do: they open the right chat, in the right mode, and the
// activity they leave behind is what "Continue learning" and the streak read next time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/activity.dart';
import 'package:tutoria/features/chat/chat_screen.dart';
import 'package:tutoria/features/home/student_home_screen.dart';

import 'support/harness.dart';

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 10, 16, 9);
  Widget home() => StudentHomeScreen(learnerId: 'l-ama', isOwn: true, now: now);

  Future<void> pickMaths(WidgetTester t) async {
    await t.pump(); // the sheet starts opening
    await t.pump(const Duration(seconds: 1));
    await t.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Mathematics'),
      ),
    );
    await t.pump(const Duration(milliseconds: 600)); // the sheet closes
    await t.pump(const Duration(milliseconds: 600)); // the chat opens
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a new learner is invited to start, not shown made-up progress', (
    t,
  ) async {
    await pumpApp(t, home(), me: studentMe);
    expect(find.text('Start your first lesson'), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // questions asked
    expect(find.text('0 days'), findsOneWidget);
    expect(find.textContaining('Last studied'), findsNothing);
  });

  testWidgets('Voice Tutor opens the chat already listening', (t) async {
    final voice = FakeVoice();
    await pumpApp(t, home(), me: studentMe, voice: voice);

    await t.tap(find.text('Voice\nTutor'));
    await pickMaths(t);

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(voice.recordings, 1);
    expect(find.textContaining('Listening'), findsOneWidget);
  });

  testWidgets('Continue learning resumes the last topic and keeps the record', (
    t,
  ) async {
    final tracker = ActivityTracker();
    await t.runAsync(
      () => tracker.record(
        'l-ama',
        subject: 'Mathematics',
        topic: 'Number: Fractions',
        now: now.subtract(const Duration(days: 1)),
      ),
    );
    final api = FakeApi(me: studentMe);
    await pumpApp(t, home(), me: studentMe, api: api, activity: tracker);

    expect(find.text('Mathematics · Number: Fractions'), findsOneWidget);
    expect(find.text('Last studied yesterday'), findsOneWidget);

    await t.tap(find.text('Continue learning').last);
    await t.pump(const Duration(milliseconds: 600));

    expect(api.asked, ['Teach me about Number: Fractions']);
    final activity = tracker.of('l-ama');
    expect(activity.questions, 2);
    expect(activity.lastTopic, 'Number: Fractions');
  });
}
