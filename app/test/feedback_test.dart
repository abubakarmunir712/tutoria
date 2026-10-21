// Client review changes: the empty-chat buttons, no curriculum diagrams in answers, the
// learner's picture in the chat and on their profile form, and the renamed labels.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/design/design.dart';
import 'package:tutoria/core/photos.dart';
import 'package:tutoria/features/chat/chat_screen.dart';
import 'package:tutoria/features/home/student_home_screen.dart';
import 'package:tutoria/features/home/subject_picker.dart';
import 'package:tutoria/features/onboarding/learner_details_screen.dart';

import 'support/harness.dart';

// A 1x1 transparent PNG: enough to stand in for a picture.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

bool isPhoto(Widget w) => w is Image && w.image is MemoryImage;

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the empty chat offers a challenge and exam prep', (t) async {
    final api = FakeApi(me: studentMe);
    await pumpApp(
      t,
      const ChatScreen(grade: 'B4', subject: 'Mathematics'),
      api: api,
    );

    expect(find.text('Tutoria Challenge'), findsOneWidget);
    expect(find.text('Start your exam prep'), findsOneWidget);
    expect(find.text('Show me an example'), findsNothing);

    await t.tap(find.text('Tutoria Challenge'));
    await t.pump(const Duration(milliseconds: 500));
    expect(api.asked.single, contains('challenge question'));
    expect(api.asked.single, contains('Mathematics'));
  });

  testWidgets('answers do not show curriculum diagrams', (t) async {
    final api = FakeApi(me: studentMe)
      ..citationImages = ['images/mathematics-page101_0.png'];
    await pumpApp(
      t,
      const ChatScreen(grade: 'B4', subject: 'Mathematics'),
      api: api,
    );

    await t.enterText(find.byType(TextField), 'What is a fraction?');
    await t.tap(find.byTooltip('Send'));
    await t.pump(const Duration(milliseconds: 500));

    // The answer and its curriculum code show; the page diagrams do not.
    expect(find.textContaining('fractions'), findsWidgets);
    expect(find.text('B4.1.3.1.1'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the learner\'s picture sits beside their own messages', (
    t,
  ) async {
    final photos = LearnerPhotos();
    await photos.set('l-ama', onePixelPng);
    await pumpApp(
      t,
      const ChatScreen(grade: 'B4', subject: 'Mathematics', learnerId: 'l-ama'),
      api: FakeApi(me: studentMe),
      photos: photos,
    );

    await t.enterText(find.byType(TextField), 'What is a fraction?');
    await t.tap(find.byTooltip('Send'));
    await t.pump(const Duration(milliseconds: 500));

    expect(find.byWidgetPredicate(isPhoto), findsOneWidget);
  });

  testWidgets('without a picture the learner\'s initials show instead', (
    t,
  ) async {
    await pumpApp(
      t,
      const ChatScreen(grade: 'B4', subject: 'Mathematics', learnerId: 'l-ama'),
      api: FakeApi(me: studentMe),
    );
    await t.enterText(find.byType(TextField), 'What is a fraction?');
    await t.tap(find.byTooltip('Send'));
    await t.pump(const Duration(milliseconds: 500));

    expect(find.byWidgetPredicate(isPhoto), findsNothing);
    expect(find.text('AM'), findsOneWidget);
  });

  testWidgets(
    'the child details form shows the saved picture and a camera badge',
    (t) async {
      final photos = LearnerPhotos();
      await photos.set('l-ama', onePixelPng);
      await pumpApp(
        t,
        const LearnerDetailsScreen(existing: ama),
        photos: photos,
      );

      expect(find.byWidgetPredicate(isPhoto), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
      expect(find.byType(Avatar), findsOneWidget);
    },
  );

  testWidgets('the home screen says Snap & Solve and Add subject', (t) async {
    await pumpApp(
      t,
      const StudentHomeScreen(learnerId: 'l-ama', isOwn: true),
      me: studentMe,
    );
    expect(find.textContaining('Snap'), findsOneWidget);
    expect(find.textContaining('Take a'), findsNothing);
    expect(find.text('Add subject'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('the subject sheet says Choose a subject', (t) async {
    await pumpApp(t, const Scaffold(body: SizedBox()), me: parentMe);
    final context = t.element(find.byType(Scaffold));
    pickSubject(context, ama);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Choose a subject'), findsOneWidget);
    expect(find.text('Which subject?'), findsNothing);
  });
}
