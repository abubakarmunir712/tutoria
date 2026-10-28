// Scores, streaks and badges as the learner and their parent see them: what the server
// reports shows up on the home screens, the rewards screen and the parent's dashboard, and
// chat tells the server who is asking and celebrates what the answer earned.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/activity.dart';
import 'package:tutoria/core/progress.dart';
import 'package:tutoria/features/chat/chat_screen.dart';
import 'package:tutoria/features/home/parent_home_screen.dart';
import 'package:tutoria/features/home/progress_screen.dart';
import 'package:tutoria/features/home/student_home_screen.dart';
import 'package:tutoria/features/progress/child_progress_screen.dart';
import 'package:tutoria/features/progress/rewards_screen.dart';

import 'support/harness.dart';

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 10, 16, 9);

  group('what the server sends', () {
    test('reads a progress summary', () {
      final p = Progress.fromJson({
        'studentId': 'l1',
        'xp': 120,
        'level': 2,
        'levelStartXp': 50,
        'nextLevelXp': 200,
        'xpIntoLevel': 70,
        'xpForLevel': 150,
        'streak': 3,
        'bestStreak': 5,
        'questions': 12,
        'photos': 1,
        'voices': 2,
        'lastSubject': 'Science',
        'lastTopic': null,
        'lastActiveAt': '2026-10-16T08:30:00.000Z',
        'bySubject': {'Science': 12},
        'days': ['2026-10-16'],
        'week': [
          {'day': '2026-10-16', 'count': 4, 'xp': 30},
        ],
        'questionsThisWeek': 4,
        'xpThisWeek': 30,
        'recentTopics': [
          {
            'subject': 'Science',
            'topic': 'Plants',
            'at': '2026-10-16T08:30:00.000Z',
          },
        ],
        'badges': [
          {
            'code': 'first_question',
            'name': 'First Steps',
            'description': 'Ask your very first question',
            'earned': true,
            'earnedAt': '2026-10-01T09:00:00.000Z',
          },
          {
            'code': 'streak_7',
            'name': 'Week Warrior',
            'description': 'Learn 7 days in a row',
            'earned': false,
            'earnedAt': null,
          },
        ],
      });
      expect(p.xpIntoLevel, 70);
      expect(p.xpForLevel, 150);
      expect(p.xpToNextLevel, 80);
      expect(p.levelFraction, closeTo(70 / 150, 1e-9));
      expect(p.earnedBadges.map((b) => b.code), ['first_question']);
      expect(p.week.single.weekday, DateTime.friday);
      expect(p.hasActivity, isTrue);
    });

    test('reads what an answer earned', () {
      final a = Award.fromJson({
        'xpGained': 40,
        'award': {'base': 10, 'firstOfDay': 10, 'streak': 20, 'total': 40},
        'xp': 90,
        'level': 2,
        'leveledUp': true,
        'streak': 3,
        'newBadges': [
          {
            'code': 'streak_3',
            'name': 'On a Roll',
            'description': 'Learn 3 days in a row',
          },
        ],
      });
      expect(a.xpGained, 40);
      expect(a.firstOfDay, 10);
      expect(a.streakBonus, 20);
      expect(a.leveledUp, isTrue);
      expect(a.newBadges.single.name, 'On a Roll');
      expect(a.newBadges.single.earned, isTrue);
      expect(a.isNews, isTrue);
    });

    test('an answer that earned nothing is not news', () {
      const a = Award(
        xpGained: 0,
        xp: 5,
        level: 1,
        leveledUp: false,
        streak: 1,
      );
      expect(a.isNews, isFalse);
    });
  });

  group('the store', () {
    test(
      'lets the server replace the phone record once it has activity',
      () async {
        final api = FakeApi(me: studentMe)..progress['l-ama'] = amaProgress();
        final tracker = ActivityTracker();
        await tracker.record('l-ama', subject: 'Science', now: now);
        final store = ProgressStore(api: api, activity: tracker);

        expect(store.of('l-ama'), isNull); // loads in the background
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(store.of('l-ama')?.xp, 120);
        final a = tracker.of('l-ama');
        expect(a.questions, 12);
        expect(a.bySubject, {'Mathematics': 8, 'Science': 4});
        expect(a.lastTopic, 'Number: Fractions');
      },
    );

    test(
      'keeps what the phone knows when the server has nothing yet',
      () async {
        final api = FakeApi(me: studentMe); // no progress on the server
        final tracker = ActivityTracker();
        await tracker.record('l-ama', subject: 'Science', now: now);
        final store = ProgressStore(api: api, activity: tracker);

        await store.refresh('l-ama');

        expect(tracker.of('l-ama').questions, 1);
        expect(tracker.of('l-ama').lastSubject, 'Science');
      },
    );

    test('a failed load leaves things as they were and is not retried on every build', () async {
      final api = _OfflineApi();
      final store = ProgressStore(api: api, activity: ActivityTracker());
      expect(store.of('l-ama'), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(store.of('l-ama'), isNull);
      expect(store.of('l-ama'), isNull);
      expect(api.attempts, 1);
    });
  });

  group('learner screens', () {
    testWidgets('home shows level, XP and how far to the next level', (
      t,
    ) async {
      final api = FakeApi(me: studentMe)..progress['l-ama'] = amaProgress();
      await pumpApp(
        t,
        StudentHomeScreen(learnerId: 'l-ama', isOwn: true, now: now),
        me: studentMe,
        api: api,
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('120 XP'), findsOneWidget);
      expect(find.text('80 XP to level 3'), findsOneWidget);
      // the streak and question count now come from the server
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('tapping the level card opens the rewards', (t) async {
      final api = FakeApi(me: studentMe)..progress['l-ama'] = amaProgress();
      await pumpApp(
        t,
        StudentHomeScreen(learnerId: 'l-ama', isOwn: true, now: now),
        me: studentMe,
        api: api,
      );
      await t.pump(const Duration(milliseconds: 300));

      await t.tap(find.text('80 XP to level 3'));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.byType(RewardsScreen), findsOneWidget);
      expect(find.text('5 of 8'), findsOneWidget);
      expect(find.text('Curious Mind'), findsOneWidget);
      expect(
        find.text('Question Machine'),
        findsOneWidget,
      ); // locked, still listed
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3));
      expect(find.text('Best streak'), findsOneWidget);
    });

    testWidgets('the progress tab shows the week and the badges won', (
      t,
    ) async {
      final api = FakeApi(me: studentMe)..progress['l-ama'] = amaProgress();
      await pumpApp(
        t,
        ProgressScreen(learnerId: 'l-ama', now: now),
        me: studentMe,
        api: api,
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('On a Roll'), findsOneWidget);
      expect(find.text('Snap and Solve'), findsOneWidget);
      expect(find.text('Week Warrior'), findsNothing); // not won yet
    });

    testWidgets(
      'a new learner starts at level 1 with an invitation to win a badge',
      (t) async {
        await pumpApp(
          t,
          ProgressScreen(learnerId: 'l-ama', now: now),
          me: studentMe,
        );
        await t.pump(const Duration(milliseconds: 300));

        expect(find.text('0 XP'), findsOneWidget);
        expect(find.text('50 XP to level 2'), findsOneWidget);
        expect(
          find.text('Ask a question to win your first badge.'),
          findsOneWidget,
        );
      },
    );
  });

  group('chat', () {
    Future<void> openChat(WidgetTester t, FakeApi api, {String? topic}) =>
        pumpApp(
          t,
          ChatScreen(
            grade: 'B4',
            subject: 'Mathematics',
            learnerId: 'l-ama',
            topic: topic,
          ),
          me: studentMe,
          api: api,
        );

    testWidgets('tells the server who asked, and about what', (t) async {
      final api = FakeApi(me: studentMe);
      await openChat(t, api, topic: 'Number: Fractions');
      await t.enterText(find.byType(TextField), 'What is a half?');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));

      expect(api.askedBy, 'l-ama');
      expect(api.askedTopic, 'Number: Fractions');
      expect(api.askedAloud, isFalse);
    });

    testWidgets('celebrates XP, a new level and a new badge', (t) async {
      final api = FakeApi(me: studentMe)
        ..award = const Award(
          xpGained: 40,
          xp: 90,
          level: 2,
          leveledUp: true,
          streak: 3,
          firstOfDay: 10,
          streakBonus: 20,
          newBadges: [
            BadgeInfo(
              code: 'streak_3',
              name: 'On a Roll',
              description: 'Learn 3 days in a row',
              earned: true,
            ),
          ],
        );
      await openChat(t, api);
      await t.enterText(find.byType(TextField), 'What is a half?');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('+40 XP'), findsOneWidget);
      expect(find.text('Level 2 reached!'), findsOneWidget);
      expect(find.text('3-day streak bonus +20 XP'), findsOneWidget);
      expect(find.text('New badge: On a Roll'), findsOneWidget);
      // and refreshed the saved score
      expect(api.progressFetches, 1);
    });

    testWidgets('says nothing when the answer earned nothing', (t) async {
      final api = FakeApi(me: studentMe)
        ..award = const Award(
          xpGained: 0,
          xp: 310,
          level: 4,
          leveledUp: false,
          streak: 1,
        );
      await openChat(t, api);
      await t.enterText(find.byType(TextField), 'What is a half?');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('marks a spoken question as spoken', (t) async {
      final api = FakeApi(me: studentMe);
      await pumpApp(
        t,
        const ChatScreen(
          grade: 'B4',
          subject: 'Mathematics',
          learnerId: 'l-ama',
          startWithVoice: true,
        ),
        me: studentMe,
        api: api,
      );
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byIcon(Icons.stop_rounded));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));

      expect(api.askedAloud, isTrue);
      expect(api.spoken, 1);
    });
  });

  group('parent dashboard', () {
    FakeApi family() => FakeApi(me: parentMe)
      ..progress['l-ama'] = amaProgress()
      ..progress['l-kofi'] = const Progress(studentId: 'l-kofi');

    testWidgets('shows every child’s streak, score and week', (t) async {
      await pumpApp(
        t,
        ParentHomeScreen(now: now),
        me: parentMe,
        api: family(),
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('120'), findsOneWidget); // Ama's XP
      expect(find.text('XP · level 2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Ama's streak
      expect(find.text('12'), findsOneWidget); // questions this week
      // Kofi has not started: a calm zero, not made-up figures
      expect(find.text('XP · level 1'), findsOneWidget);
      expect(find.text('View progress'), findsNWidgets(2));
    });

    testWidgets('View progress opens the child’s full picture', (t) async {
      await pumpApp(
        t,
        ParentHomeScreen(now: now),
        me: parentMe,
        api: family(),
      );
      await t.pump(const Duration(milliseconds: 300));

      await t.tap(find.text('View progress').first);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));

      expect(find.byType(ChildProgressScreen), findsOneWidget);
      // the whole page, not just the top (a list only builds what is on screen)
      t.view.physicalSize = const Size(1170, 4800);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Ama’s progress'), findsOneWidget);
      expect(find.text('Questions this week'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Mathematics'), findsWidgets);
      expect(find.text('8 questions'), findsOneWidget);
      expect(find.text('Number: Fractions'), findsOneWidget);
      expect(find.text('Parts of a Plant'), findsOneWidget);
      expect(find.text('5 of 8'), findsOneWidget);
      expect(find.textContaining('Active '), findsOneWidget);
    });

    testWidgets('says when the child was last active', (t) async {
      await pumpApp(
        t,
        ChildProgressScreen(learnerId: 'l-ama', now: now),
        me: parentMe,
        api: family(),
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('Active today'), findsOneWidget);
      expect(find.text('Class 4'), findsOneWidget);
    });

    testWidgets('a child who has not started says so kindly', (t) async {
      await pumpApp(
        t,
        const ChildProgressScreen(learnerId: 'l-kofi'),
        me: parentMe,
        api: family(),
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(
        find.textContaining('Kofi hasn’t asked a question yet'),
        findsOneWidget,
      );
      expect(find.text('Last 7 days'), findsNothing);
      expect(find.text('Open Kofi’s tutor'), findsOneWidget);
    });
  });
}

class _OfflineApi extends FakeApi {
  var attempts = 0;

  @override
  Future<Progress> getProgress(String learnerId) async {
    attempts++;
    throw Exception('offline');
  }
}
