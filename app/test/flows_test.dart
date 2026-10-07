// Drives the real screens and routing through sign-up, onboarding and login, against an
// in-memory stand-in for the server (see FakeServer).
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tutoria/app.dart';
import 'package:tutoria/core/api_client.dart';
import 'package:tutoria/core/models.dart';
import 'package:tutoria/features/auth/auth_state.dart';

import 'support/harness.dart';

/// Behaves like the server for accounts: signup makes a user (and a student's own profile),
/// children are added and updated, subjects are checked against the class's phase.
class FakeServer extends FakeApi {
  FakeServer() : super();

  final _users = <String, ({String password, UserRole role, String name, String email, String phone})>{};
  final _learners = <String, List<Learner>>{};
  String? _current;
  var _next = 0;

  Map<String, dynamic> _tokens(String id) {
    _current = id;
    return {'accessToken': 'access-$id', 'refreshToken': 'refresh-$id'};
  }

  @override
  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    if (_users.containsKey(email)) throw ApiException(409, 'Email or phone already registered');
    final id = 'user-${_next++}';
    _users[email] = (password: password, role: role, name: fullName, email: email, phone: phone);
    _ids[email] = id;
    _learners[id] = role == UserRole.student ? [Learner(id: 'learner-${_next++}', name: fullName)] : [];
    return _tokens(id);
  }

  final _ids = <String, String>{};

  @override
  Future<Map<String, dynamic>> login({required String identifier, required String password}) async {
    final user = _users[identifier];
    if (user == null || user.password != password) throw ApiException(401, 'Invalid credentials');
    return _tokens(_ids[identifier]!);
  }

  @override
  Future<Me> getMe() async {
    final entry = _ids.entries.firstWhere((e) => e.value == _current);
    final u = _users[entry.key]!;
    return Me(id: entry.value, fullName: u.name, email: u.email, phone: u.phone, role: u.role, learners: _learners[entry.value]!);
  }

  @override
  Future<Learner> createLearner({required String name, required String grade, String? schoolType}) async {
    final learner = Learner(id: 'learner-${_next++}', name: name, grade: grade, schoolType: schoolType);
    _learners[_current!]!.add(learner);
    return learner;
  }

  @override
  Future<Learner> updateLearner(String id, {String? name, String? grade, String? schoolType}) async {
    final list = _learners[_current!]!;
    final i = list.indexWhere((l) => l.id == id);
    final old = list[i];
    return list[i] = Learner(id: id, name: name ?? old.name, grade: grade ?? old.grade, schoolType: schoolType ?? old.schoolType, subjects: old.subjects);
  }

  @override
  Future<Learner> setSubjects(String learnerId, List<String> subjectIds) async {
    final list = _learners[_current!]!;
    final i = list.indexWhere((l) => l.id == learnerId);
    final old = list[i];
    return list[i] = Learner(
      id: old.id,
      name: old.name,
      grade: old.grade,
      schoolType: old.schoolType,
      subjects: subjects.where((s) => subjectIds.contains(s.id)).toList(),
    );
  }
}

Future<void> boot(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(TutoriaApp(api: server));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String hint, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, hint).first, text);
}

Future<void> pickClass(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a signed-out user lands on the welcome screen', (tester) async {
    await boot(tester, FakeServer());
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('start here'), findsOneWidget);
  });

  testWidgets('parent: sign up, add a child, choose subjects, land on their home', (tester) async {
    final server = FakeServer();
    await boot(tester, server);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I’m a Parent'));
    await tester.pumpAndSettle();

    // Step 1: empty form is refused with messages, nothing is sent.
    await tester.tap(find.widgetWithText(InkWell, 'Create Account').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await fill(tester, 'Full name', 'Esi Mensah');
    await fill(tester, 'Email address', 'esi@example.com');
    await fill(tester, 'Phone number', '0241234567');
    await fill(tester, 'Password', 'correct-horse-9');
    await tester.tap(find.widgetWithText(InkWell, 'Create Account').last);
    await tester.pumpAndSettle();

    // Step 2: a parent with no children is taken straight to "tell us about your child".
    expect(find.text('Tell us about your child'), findsOneWidget);
    await tester.tap(find.widgetWithText(InkWell, 'Next').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Choose a class'), findsWidgets);

    await fill(tester, 'e.g. Ama', 'Ama');
    await pickClass(tester, 'Class 4');
    await tester.tap(find.widgetWithText(InkWell, 'Next').last);
    await tester.pumpAndSettle();

    // Step 3: pick subjects; Finish needs at least one.
    expect(find.text('What would you like\nhelp with?'), findsOneWidget);
    await tester.tap(find.text('Mathematics'));
    await tester.tap(find.text('Science'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Finish').last);
    await tester.pumpAndSettle();

    // Done: the parent's home lists the child with the chosen subjects.
    expect(find.text('Your children'), findsOneWidget);
    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('Class 4'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('English'), findsNothing);
  });

  testWidgets('student: sign up, say class and subjects, land on their own home', (tester) async {
    await boot(tester, FakeServer());

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I’m a Student'));
    await tester.pumpAndSettle();

    await fill(tester, 'Your full name', 'Kofi Boateng');
    await fill(tester, 'Email address', 'kofi@example.com');
    await fill(tester, 'Phone number', '0551234567');
    await fill(tester, 'Password', 'correct-horse-9');
    await tester.tap(find.widgetWithText(InkWell, 'Create Account').last);
    await tester.pumpAndSettle();

    expect(find.text('Tell us about you'), findsOneWidget);
    await pickClass(tester, 'Class 5');
    await tester.tap(find.widgetWithText(InkWell, 'Next').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('English Language'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Finish').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Hi Kofi'), findsOneWidget);
    expect(find.text('Class 5'), findsOneWidget);
    expect(find.text('Ask\nTutoria'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('a returning user signs in and a wrong password is refused', (tester) async {
    final server = FakeServer();
    await server.signup(fullName: 'Esi Mensah', email: 'esi@example.com', phone: '+233241234567', password: 'correct-horse-9', role: UserRole.parent);
    final ama = await server.createLearner(name: 'Ama', grade: 'B4');
    await server.setSubjects(ama.id, ['s-maths']);
    await boot(tester, server);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    await fill(tester, 'Email or phone number', 'esi@example.com');
    await fill(tester, 'Password', 'wrong-password');
    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();
    expect(find.text('Invalid credentials'), findsOneWidget);
    expect(find.text('Your children'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password').first, 'correct-horse-9');
    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();
    expect(find.text('Your children'), findsOneWidget);
    expect(find.text('Ama'), findsOneWidget);
  });

  testWidgets('logging out returns to the welcome screen', (tester) async {
    final server = FakeServer();
    await server.signup(fullName: 'Esi Mensah', email: 'esi@example.com', phone: '+233241234567', password: 'correct-horse-9', role: UserRole.parent);
    await server.createLearner(name: 'Ama', grade: 'B4');
    await boot(tester, server);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    await fill(tester, 'Email or phone number', 'esi@example.com');
    await fill(tester, 'Password', 'correct-horse-9');
    await tester.tap(find.widgetWithText(InkWell, 'Sign In').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.element(find.byType(MaterialApp)).read<AuthState>().me, isNull);
  });
}
