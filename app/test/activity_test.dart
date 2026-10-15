import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 16, 9);

  LearnerActivity daysAgo(List<int> offsets) => LearnerActivity(
    lastSubject: 'Mathematics',
    days: [
      for (final o in offsets)
        dayKey(DateTime(now.year, now.month, now.day - o)),
    ],
  );

  group('streak', () {
    test('no activity is no streak', () {
      expect(LearnerActivity.empty.streakAt(now), 0);
    });
    test('counts consecutive days ending today', () {
      expect(daysAgo([2, 1, 0]).streakAt(now), 3);
    });
    test('is kept until the end of tomorrow if today has no activity yet', () {
      expect(daysAgo([2, 1]).streakAt(now), 2);
    });
    test('is lost after a missed day', () {
      expect(daysAgo([3, 2]).streakAt(now), 0);
    });
    test('a gap ends the run', () {
      expect(daysAgo([5, 4, 1, 0]).streakAt(now), 2);
    });
  });

  group('recording', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'remembers the last topic, counts questions per subject and saves them',
      () async {
        final tracker = ActivityTracker();
        await tracker.record(
          'l1',
          subject: 'Mathematics',
          topic: 'Fractions',
          now: now,
        );
        await tracker.record('l1', subject: 'Mathematics', now: now);
        await tracker.record('l1', subject: 'Science', now: now);

        final a = tracker.of('l1');
        expect(a.questions, 3);
        expect(a.bySubject, {'Mathematics': 2, 'Science': 1});
        expect(a.lastSubject, 'Science');
        expect(a.days, [dayKey(now)]);

        // A fresh tracker (the app restarted) reads it back.
        final again = ActivityTracker();
        again.of('l1');
        await Future<void>.delayed(Duration.zero);
        expect(again.of('l1').questions, 3);
      },
    );

    test('learners are kept apart', () async {
      final tracker = ActivityTracker();
      await tracker.record('l1', subject: 'Mathematics', now: now);
      expect(tracker.of('l2').hasActivity, isFalse);
    });
  });
}
