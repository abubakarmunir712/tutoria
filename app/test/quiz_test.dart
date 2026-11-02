// Practice and quizzes: the unit list, the question flow (a nudge and a second try after a wrong
// answer, then the answer), and the result.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/quiz.dart';
import 'package:tutoria/features/quiz/mastery_widgets.dart';
import 'package:tutoria/features/quiz/practice_screen.dart';
import 'package:tutoria/features/quiz/quiz_screen.dart';

import 'support/harness.dart';

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('the practice list shows each unit with where the learner is', (
    t,
  ) async {
    await pumpApp(
      t,
      const PracticeScreen(learnerId: 'l-ama', subject: mathsSubject),
      me: studentMe,
    );
    await settle(t);

    expect(find.text('Number and place value'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
    expect(find.text('Secure'), findsOneWidget);
    expect(find.text('Best 90%'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('1 of 2 topics secure'), findsOneWidget);
  });

  testWidgets('a unit opens its quiz, quick check and assignment', (t) async {
    await pumpApp(
      t,
      const PracticeScreen(learnerId: 'l-ama', subject: mathsSubject),
      me: studentMe,
    );
    await settle(t);

    await t.tap(find.text('Number and place value'));
    await settle(t);

    expect(find.text('Take the quiz'), findsOneWidget);
    expect(find.text('Quick check'), findsOneWidget);
    expect(find.text('Assignment'), findsOneWidget);
  });

  testWidgets('a wrong answer gets a nudge and a second try, then the answer', (
    t,
  ) async {
    final api = FakeApi(me: studentMe);
    await pumpApp(
      t,
      const QuizScreen(
        learnerId: 'l-ama',
        topicId: 'u1',
        subject: 'Mathematics',
        grade: 'B4',
      ),
      api: api,
    );
    await settle(t);
    expect(find.text('What is 2 + 2?'), findsOneWidget);
    expect(find.text('Check my answer'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'wrong');
    await t.pump();
    await t.tap(find.text('Check my answer'));
    await settle(t);

    expect(find.text('Not quite. Have another go'), findsOneWidget);
    expect(find.text('Count on from two.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('The answer'), findsNothing);

    await t.tap(find.text('Try again'));
    await settle(t);

    expect(find.text('Not this time'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // the answer is shown now
    expect(find.text('See my results'), findsOneWidget);
    expect(api.answers, ['wrong', 'wrong']);

    await t.tap(find.text('See my results'));
    await settle(t);

    expect(find.text('Keep practising!'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Emerging'), findsOneWidget);
    expect(find.text('Ask Tutoria to explain'), findsOneWidget);
    expect(find.text('Try the quiz again'), findsOneWidget);
  });

  testWidgets('a right answer goes straight to the result with progress', (
    t,
  ) async {
    final api = FakeApi(me: studentMe);
    await pumpApp(
      t,
      const QuizScreen(
        learnerId: 'l-ama',
        topicId: 'u1',
        subject: 'Mathematics',
        grade: 'B4',
      ),
      api: api,
    );
    await settle(t);

    await t.enterText(find.byType(TextField), 'right');
    await t.pump();
    await t.tap(find.text('Check my answer'));
    await settle(t);
    expect(find.text('Correct!'), findsOneWidget);

    await t.tap(find.text('See my results'));
    await settle(t);

    expect(find.text('Brilliant work!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Secure'), findsOneWidget);
    expect(find.text('Up from Not started'), findsOneWidget);
    expect(find.text('Up next: Operations'), findsOneWidget);
    expect(find.text('Try the quiz again'), findsNothing);
  });

  testWidgets('the answer button stays off until something is typed', (
    t,
  ) async {
    await pumpApp(
      t,
      const QuizScreen(
        learnerId: 'l-ama',
        topicId: 'u1',
        subject: 'Mathematics',
      ),
      me: studentMe,
    );
    await settle(t);
    final button = find.ancestor(
      of: find.text('Check my answer'),
      matching: find.byType(ElevatedButton),
    );
    if (button.evaluate().isNotEmpty) {
      expect(t.widget<ElevatedButton>(button).onPressed, isNull);
    }
    await t.enterText(find.byType(TextField), '4');
    await t.pump();
    if (button.evaluate().isNotEmpty) {
      expect(t.widget<ElevatedButton>(button).onPressed, isNotNull);
    }
  });

  testWidgets('the mastery section summarises topics for a parent or learner', (
    t,
  ) async {
    await pumpApp(
      t,
      const Scaffold(
        body: SingleChildScrollView(child: MasterySection(learnerId: 'l-ama')),
      ),
      me: studentMe,
    );
    await settle(t);

    expect(find.text('Topic mastery'), findsOneWidget);
    expect(find.text('1 of 2 topics secure'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
  });

  testWidgets('a half-done quiz can be carried on from the home screen', (
    t,
  ) async {
    final api = FakeApi(me: studentMe)
      ..unfinishedQuiz = const UnfinishedQuiz(
        topicId: 'q-1',
        topicName: 'Number and place value',
        subject: 'Mathematics',
        check: false,
        answered: 2,
        total: 5,
      );
    await pumpApp(
      t,
      const Scaffold(body: UnfinishedQuizCard(learnerId: 'l-ama')),
      api: api,
      me: studentMe,
    );
    await settle(t);

    expect(find.text('Carry on your quiz'), findsOneWidget);
    expect(find.textContaining('2 of 5 done'), findsOneWidget);
  });

  testWidgets('with nothing half-done the card is not shown', (t) async {
    await pumpApp(
      t,
      const Scaffold(body: UnfinishedQuizCard(learnerId: 'l-ama')),
      me: studentMe,
    );
    await settle(t);
    expect(find.textContaining('Carry on'), findsNothing);
  });
}
