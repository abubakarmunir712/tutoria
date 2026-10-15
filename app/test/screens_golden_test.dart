// Renders each screen to a PNG (test/goldens/) and fails if a later change alters one, so the
// look can't drift unnoticed. After a deliberate design change, refresh them with:
//   flutter test --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/activity.dart';
import 'package:tutoria/core/models.dart';
import 'package:tutoria/features/auth/auth_state.dart';
import 'package:tutoria/features/auth/login_screen.dart';
import 'package:tutoria/features/auth/signup_screen.dart';
import 'package:tutoria/features/chat/chat_screen.dart';
import 'package:tutoria/features/home/main_shell.dart';
import 'package:tutoria/features/home/parent_home_screen.dart';
import 'package:tutoria/features/home/ask_screen.dart';
import 'package:tutoria/features/home/learn_screen.dart';
import 'package:tutoria/features/home/progress_screen.dart';
import 'package:tutoria/features/home/student_home_screen.dart';
import 'package:tutoria/features/onboarding/learner_details_screen.dart';
import 'package:tutoria/features/onboarding/subjects_screen.dart';
import 'package:tutoria/features/onboarding/user_type_screen.dart';
import 'package:tutoria/features/onboarding/welcome_screen.dart';
import 'package:tutoria/features/subjects/subject_screen.dart';

import 'support/harness.dart';
import 'support/palette_sheet.dart';

Future<void> golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

final morning = DateTime(2026, 10, 16, 9);

/// A learner who has asked about Maths (fractions) and Science over the last three days.
Future<ActivityTracker> busyLearner() async {
  SharedPreferences.setMockInitialValues({});
  final tracker = ActivityTracker();
  for (final (days, subject, topic) in [
    (2, 'Science', null),
    (1, 'Mathematics', null),
    (0, 'Mathematics', 'Number: Fractions'),
  ]) {
    await tracker.record(
      'l-ama',
      subject: subject,
      topic: topic,
      now: DateTime(2026, 10, 16 - days, 9),
    );
  }
  await tracker.record('l-ama', subject: 'Mathematics', now: morning);
  return tracker;
}

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('onboarding', () {
    testWidgets('welcome', (t) async {
      await pumpApp(
        t,
        const WelcomeScreen(),
        status: AuthStatus.unauthenticated,
      );
      await golden(t, 'welcome');
    });
    testWidgets('user type', (t) async {
      await pumpApp(
        t,
        const UserTypeScreen(),
        status: AuthStatus.unauthenticated,
      );
      await golden(t, 'user_type');
    });
    testWidgets('sign up', (t) async {
      await pumpApp(
        t,
        const SignupScreen(role: UserRole.parent),
        status: AuthStatus.unauthenticated,
      );
      await golden(t, 'signup');
    });
    testWidgets('login', (t) async {
      await pumpApp(t, const LoginScreen(), status: AuthStatus.unauthenticated);
      await golden(t, 'login');
    });
    testWidgets('child details', (t) async {
      await pumpApp(
        t,
        const LearnerDetailsScreen(onboarding: true),
        me: const Me(
          id: 'u',
          fullName: 'Esi Mensah',
          email: 'e@x.com',
          phone: '+233241234567',
          role: UserRole.parent,
          learners: [],
        ),
      );
      await golden(t, 'child_details');
    });
    testWidgets('subjects', (t) async {
      await pumpApp(
        t,
        const SubjectsScreen(learnerId: 'l-ama', onboarding: true),
        me: parentMe,
      );
      await t.pump(const Duration(milliseconds: 300));
      await golden(t, 'subjects');
    });
  });

  group('signed in', () {
    testWidgets('parent home', (t) async {
      await pumpApp(t, ParentHomeScreen(now: morning), me: parentMe);
      await golden(t, 'parent_home');
    });
    testWidgets('student home', (t) async {
      await pumpApp(
        t,
        StudentHomeScreen(learnerId: 'l-ama', isOwn: true, now: morning),
        me: studentMe,
      );
      await golden(t, 'student_home');
    });
    testWidgets('student home, with progress', (t) async {
      final tracker = await t.runAsync(busyLearner);
      await pumpApp(
        t,
        StudentHomeScreen(learnerId: 'l-ama', isOwn: true, now: morning),
        me: studentMe,
        activity: tracker,
      );
      t.view.physicalSize = const Size(
        1170,
        3300,
      ); // the whole page, not just the top
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Good morning, Ama!'), findsOneWidget);
      expect(find.text('Mathematics'), findsWidgets);
      expect(find.text('Last studied today'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // questions asked
      expect(find.text('3 days'), findsOneWidget); // streak
      await golden(t, 'student_home_progress');
    });
    testWidgets('student tabs', (t) async {
      await pumpApp(t, const MainShell(), me: studentMe);
      for (final tab in ['Home', 'Learn', 'Ask', 'Progress', 'Profile']) {
        expect(find.text(tab), findsWidgets);
      }
      await golden(t, 'student_shell');
    });
    testWidgets('learn tab', (t) async {
      await pumpApp(t, const LearnScreen(learnerId: 'l-ama'), me: studentMe);
      await golden(t, 'learn_tab');
    });
    testWidgets('ask tab', (t) async {
      await pumpApp(t, const AskScreen(learnerId: 'l-ama'), me: studentMe);
      await golden(t, 'ask_tab');
    });
    testWidgets('progress tab, no activity yet', (t) async {
      await pumpApp(
        t,
        ProgressScreen(learnerId: 'l-ama', now: morning),
        me: studentMe,
      );
      await golden(t, 'progress_tab_empty');
    });
    testWidgets('progress tab, with activity', (t) async {
      final tracker = await t.runAsync(busyLearner);
      await pumpApp(
        t,
        ProgressScreen(learnerId: 'l-ama', now: morning),
        me: studentMe,
        activity: tracker,
      );
      await golden(t, 'progress_tab');
    });
    testWidgets('student home, no subjects yet', (t) async {
      const bare = Learner(id: 'l-ama', name: 'Ama Mensah', grade: 'B4');
      await pumpApp(
        t,
        StudentHomeScreen(learnerId: 'l-ama', isOwn: true, now: morning),
        me: const Me(
          id: 'u',
          fullName: 'Ama Mensah',
          email: 'a@x.com',
          phone: '+233241234568',
          role: UserRole.student,
          learners: [bare],
        ),
      );
      await golden(t, 'student_home_empty');
    });
    testWidgets('subject topics', (t) async {
      await pumpApp(
        t,
        const SubjectScreen(learnerId: 'l-ama', subject: mathsSubject),
        me: parentMe,
      );
      await t.pump(const Duration(milliseconds: 300));
      await golden(t, 'subject_topics');
    });
    testWidgets('profile (parent)', (t) async {
      await pumpApp(t, const MainShell(), me: parentMe);
      await t.tap(find.text('Profile'));
      await t.pump(const Duration(milliseconds: 300));
      await golden(t, 'profile_parent');
    });
  });

  group('chat', () {
    testWidgets('empty', (t) async {
      await pumpApp(
        t,
        const ChatScreen(grade: 'B4', subject: 'Mathematics'),
        me: studentMe,
      );
      await golden(t, 'chat_empty');
    });
    testWidgets('conversation', (t) async {
      final api = FakeApi(me: studentMe);
      await pumpApp(
        t,
        const ChatScreen(
          grade: 'B4',
          subject: 'Mathematics',
          initialQuestion: 'Teach me about Number: Fractions',
        ),
        api: api,
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(api.asked, ['Teach me about Number: Fractions']);
      await golden(t, 'chat_conversation');
    });
  });

  testWidgets('palette sheet', (t) async {
    await pumpApp(t, const PaletteSheet(), me: studentMe);
    t.view.physicalSize = const Size(1170, 5400);
    await t.pump(const Duration(milliseconds: 300));
    await golden(t, 'palette');
  });
}
