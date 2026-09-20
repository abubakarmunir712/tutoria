import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tutoria/app.dart';

void main() {
  testWidgets('App boots to the login screen when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TutoriaApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
  });
}
