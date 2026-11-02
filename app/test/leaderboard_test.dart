// The class leaderboard: ranked rows with the learner highlighted, an empty state, and stepping
// off the board.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutoria/core/leaderboard.dart';
import 'package:tutoria/features/progress/leaderboard_screen.dart';

import 'support/harness.dart';

void main() {
  setUpAll(loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('shows the class ranking with the learner marked', (t) async {
    await pumpApp(
      t,
      const LeaderboardScreen(learnerId: 'l-ama'),
      me: studentMe,
    );
    await settle(t);

    expect(find.text('Kwame A.'), findsOneWidget);
    expect(find.text('Ama M. (you)'), findsOneWidget);
    expect(find.text('60 XP'), findsOneWidget);
  });

  testWidgets('says so when no one has earned XP yet', (t) async {
    final api = FakeApi(me: studentMe)..board = const Leaderboard(top: []);
    await pumpApp(
      t,
      const LeaderboardScreen(learnerId: 'l-ama'),
      api: api,
      me: studentMe,
    );
    await settle(t);
    expect(find.textContaining('No one has earned XP'), findsOneWidget);
  });

  testWidgets('a learner can step off the board', (t) async {
    final api = FakeApi(me: studentMe);
    await pumpApp(
      t,
      const LeaderboardScreen(learnerId: 'l-ama'),
      api: api,
      me: studentMe,
    );
    await settle(t);

    await t.tap(find.byType(Switch));
    await settle(t);
    expect(api.boardVisibility, [false]);
  });
}
