// The voice path in the chat: talk to ask, hear the answer, and what happens when the microphone
// is refused. The microphone, speaker and server are stand-ins (FakeVoice, FakeApi).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutoria/features/chat/chat_screen.dart';

import 'support/harness.dart';

Future<void> open(WidgetTester t, FakeApi api, FakeVoice voice) => pumpApp(
  t,
  const ChatScreen(grade: 'B4', subject: 'Mathematics'),
  api: api,
  voice: voice,
);

void main() {
  setUpAll(loadFonts);

  testWidgets(
    'speaking a question sends it as text and reads the answer aloud',
    (t) async {
      final api = FakeApi(me: studentMe);
      final voice = FakeVoice();
      await open(t, api, voice);

      await t.tap(find.byTooltip('Ask with your voice'));
      await t.pump();
      expect(voice.recordings, 1);
      expect(find.textContaining('Listening'), findsOneWidget);
      // Typing is off while listening, and the mic button becomes the stop button.
      expect(find.byType(TextField), findsNothing);

      await t.tap(find.byTooltip('Stop and send'));
      await t.pump(const Duration(milliseconds: 500));

      // The child's words show as their own message and go through the normal ask.
      expect(api.asked, ['How do I add fractions?']);
      expect(find.text('How do I add fractions?'), findsOneWidget);
      // The answer to a spoken question is read aloud without another tap.
      expect(api.spoken, 1);
      expect(voice.played, 1);
    },
  );

  testWidgets('a typed question is not read aloud until Listen is tapped', (
    t,
  ) async {
    final api = FakeApi(me: studentMe);
    final voice = FakeVoice();
    await open(t, api, voice);

    await t.enterText(find.byType(TextField), 'What is a fraction?');
    await t.tap(find.byTooltip('Send'));
    await t.pump(const Duration(milliseconds: 500));
    expect(api.spoken, 0);

    await t.tap(find.text('Listen'));
    await t.pump(const Duration(milliseconds: 500));
    expect(api.spoken, 1);
    expect(voice.played, 1);
  });

  testWidgets(
    'nothing heard asks the child to try again instead of sending an empty question',
    (t) async {
      final api = FakeApi(me: studentMe)..heard = '';
      final voice = FakeVoice();
      await open(t, api, voice);

      await t.tap(find.byTooltip('Ask with your voice'));
      await t.pump();
      await t.tap(find.byTooltip('Stop and send'));
      await t.pump(const Duration(milliseconds: 500));

      expect(api.asked, isEmpty);
      expect(find.textContaining("couldn't hear a question"), findsOneWidget);
    },
  );

  testWidgets('a refused microphone explains how to allow it', (t) async {
    final api = FakeApi(me: studentMe);
    final voice = FakeVoice(micAllowed: false);
    await open(t, api, voice);

    await t.tap(find.byTooltip('Ask with your voice'));
    await t.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Allow microphone access'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
