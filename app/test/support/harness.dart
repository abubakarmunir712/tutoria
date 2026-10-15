import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tutoria/core/api_client.dart';
import 'package:tutoria/core/design/design.dart';
import 'package:tutoria/core/models.dart';
import 'package:tutoria/core/voice.dart';
import 'package:tutoria/features/auth/auth_state.dart';

/// Loads the real fonts so screens render as they do on a phone (tests default to a block font).
Future<void> loadFonts() async {
  final nunito = FontLoader('Nunito')
    ..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
  await nunito.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

const mathsSubject = Subject(
  id: 's-maths',
  name: 'Mathematics',
  phase: 'UPPER_PRIMARY',
);
const englishSubject = Subject(
  id: 's-eng',
  name: 'English Language',
  phase: 'UPPER_PRIMARY',
);
const scienceSubject = Subject(
  id: 's-sci',
  name: 'Science',
  phase: 'UPPER_PRIMARY',
);
const worldSubject = Subject(
  id: 's-world',
  name: 'Our World and Our People',
  phase: 'UPPER_PRIMARY',
);
const computingSubject = Subject(
  id: 's-comp',
  name: 'Computing',
  phase: 'UPPER_PRIMARY',
);

const ama = Learner(
  id: 'l-ama',
  name: 'Ama Mensah',
  grade: 'B4',
  schoolType: 'PRIVATE',
  subjects: [mathsSubject, englishSubject, scienceSubject],
);
const kofi = Learner(
  id: 'l-kofi',
  name: 'Kofi Mensah',
  grade: 'B8',
  schoolType: 'PUBLIC',
  subjects: [
    Subject(id: 's-maths-jhs', name: 'Mathematics', phase: 'JHS'),
    Subject(id: 's-soc', name: 'Social Studies', phase: 'JHS'),
  ],
);

const parentMe = Me(
  id: 'u-esi',
  fullName: 'Esi Mensah',
  email: 'esi.mensah@example.com',
  phone: '+233241234567',
  role: UserRole.parent,
  learners: [ama, kofi],
);

const studentMe = Me(
  id: 'u-ama',
  fullName: 'Ama Mensah',
  email: 'ama.mensah@example.com',
  phone: '+233241234568',
  role: UserRole.student,
  learners: [ama],
);

final mathsTopics = [
  const CurriculumStrand(
    name: 'Number',
    topics: [
      CurriculumTopic(
        name: 'Counting, Representation & Cardinality',
        lessons: 13,
      ),
      CurriculumTopic(name: 'Number Operations', lessons: 7),
      CurriculumTopic(name: 'Number: Fractions', lessons: 6),
      CurriculumTopic(name: 'Decimal Fractions', lessons: 5),
      CurriculumTopic(name: 'Understanding Percentages', lessons: 3),
    ],
  ),
  const CurriculumStrand(
    name: 'Algebra',
    topics: [
      CurriculumTopic(name: 'Patterns and Relationships', lessons: 8),
      CurriculumTopic(name: 'Algebraic Expressions', lessons: 1),
    ],
  ),
];

/// An API that answers from memory, so screens render without a server.
class FakeApi extends ApiClient {
  FakeApi({
    this.me = parentMe,
    this.subjects = const [
      mathsSubject,
      englishSubject,
      scienceSubject,
      worldSubject,
      computingSubject,
    ],
  });

  Me me;
  List<Subject> subjects;
  final asked = <String>[];

  /// What the fake recogniser "heard" for a spoken question, and how many replies were read out.
  String heard = 'How do I add fractions?';
  var spoken = 0;

  @override
  Future<String> transcribeAudio(File audio) async => heard;

  @override
  Future<Uint8List> speak(String text) async {
    spoken++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Me> getMe() async => me;

  @override
  Future<List<Subject>> listSubjects({required String grade}) async => subjects;

  @override
  Future<List<CurriculumStrand>> topics({
    required String grade,
    required String subject,
  }) async => mathsTopics;

  @override
  Future<ChatResponse> askQuestion({
    required String question,
    String? grade,
    String? subject,
    List<Map<String, String>>? history,
  }) async {
    asked.add(question);
    return ChatResponse(
      answer:
          'Great question! Before we start, what do you already know about **fractions**?\n\n'
          'Think of a pizza cut into 8 equal slices. If you eat 3 slices, what fraction did you eat?',
      citations: [
        ChatCitation(
          indicatorCode: 'B4.1.3.1.1',
          strand: 'Number',
          substrand: 'Fractions',
          images: const [],
        ),
      ],
    );
  }
}

/// A microphone and speaker that need no device.
class FakeVoice implements VoiceService {
  FakeVoice({this.micAllowed = true});

  final bool micAllowed;
  var recordings = 0;
  var played = 0;
  var stopped = 0;

  @override
  Future<bool> startRecording() async {
    if (micAllowed) recordings++;
    return micAllowed;
  }

  @override
  Future<File?> stopRecording() async => File('/tmp/fake-question.m4a');

  @override
  Future<void> play(Uint8List audio, {String mimeType = 'audio/wav'}) async =>
      played++;

  @override
  Future<void> stopPlayback() async => stopped++;

  @override
  void dispose() {}
}

/// A phone-sized, themed app around [home], with the API and auth state the screens expect.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  FakeApi? api,
  Me? me,
  FakeVoice? voice,
  AuthStatus status = AuthStatus.authenticated,
}) async {
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical at 3x
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final fake = api ?? FakeApi(me: me ?? parentMe);
  final auth = AuthState(api: fake)
    ..debugSet(status: status, me: me ?? fake.me);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: fake),
        Provider<VoiceService>.value(value: voice ?? FakeVoice()),
        ChangeNotifierProvider<AuthState>.value(value: auth),
      ],
      child: MaterialApp(
        theme: buildTutoriaTheme(),
        debugShowCheckedModeBanner: false,
        home: home,
      ),
    ),
  );
  // Decode the artwork before settling, so screens that show it aren't captured mid-load.
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    for (final asset in const [
      'logo_mark',
      'mascot_hero',
      'role_parent',
      'role_student',
    ]) {
      await precacheImage(AssetImage('assets/images/$asset.png'), context);
    }
  });
  // Settle async loads and transitions without waiting on endless animations (typing dots).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
