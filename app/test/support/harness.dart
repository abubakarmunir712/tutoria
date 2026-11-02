import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tutoria/core/activity.dart';
import 'package:tutoria/core/api_client.dart';
import 'package:tutoria/core/design/design.dart';
import 'package:tutoria/core/models.dart';
import 'package:tutoria/core/photos.dart';
import 'package:tutoria/core/progress.dart';
import 'package:tutoria/core/quiz.dart';
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

  /// Curriculum diagram paths the fake server attaches to every answer.
  List<String> citationImages = const [];

  /// What the fake recogniser "heard" for a spoken question, and how many replies were read out.
  String heard = 'How do I add fractions?';
  var spoken = 0;

  /// What the fake server reports for each learner, and the award it attaches to answers.
  final progress = <String, Progress>{};
  Award? award;
  var progressFetches = 0;

  /// Practice: the units the fake server lists, and the quiz it runs (one question that is
  /// right when answered "right"; "wrong" is nudged once, then revealed).
  var units = <PracticeUnit>[
    const PracticeUnit(
      id: 'u1',
      name: 'Number and place value',
      strand: 'Number',
      order: 1,
      mastery: Mastery.notStarted,
      recommended: true,
    ),
    const PracticeUnit(
      id: 'u2',
      name: 'Operations',
      strand: 'Number',
      order: 2,
      mastery: Mastery.secure,
      bestScore: 0.9,
      attempts: 2,
    ),
  ];
  final answers = <String>[];
  var tries = 0;

  @override
  Future<PracticeList> practiceUnits({
    required String learnerId,
    required String subject,
  }) async => PracticeList(
    subject: subject,
    summary: const MasterySummary(total: 2, started: 1, secure: 1),
    units: units,
  );

  @override
  Future<MasteryOverview> masteryOverview(String learnerId) async =>
      MasteryOverview(
        studentId: learnerId,
        summary: const MasterySummary(total: 2, started: 1, secure: 1),
        bySubject: const [
          SubjectMastery(
            subject: 'Mathematics',
            summary: MasterySummary(total: 2, started: 1, secure: 1),
          ),
        ],
        needsRevision: const [],
      );

  @override
  Future<QuizAttempt> startQuiz({
    required String learnerId,
    required String topicId,
    required bool check,
  }) async {
    tries = 0;
    return QuizAttempt(
      attemptId: 'a1',
      isCheck: check,
      topicId: topicId,
      topicName: 'Number and place value',
      subject: 'Mathematics',
      questions: const [
        QuizQuestion(
          id: 'q1',
          order: 1,
          levelLabel: 'Foundations',
          text: 'What is 2 + 2?',
        ),
      ],
    );
  }

  @override
  Future<AnswerOutcome> answerQuestion({
    required String attemptId,
    required String questionId,
    required String answer,
  }) async {
    answers.add(answer);
    tries++;
    if (answer == 'right') {
      return AnswerOutcome(
        settled: true,
        verdict: Verdict.correct,
        feedback: 'Correct. Well done!',
        done: true,
        result: QuizResult(
          percent: tries == 1 ? 100 : 60,
          correct: 1,
          total: 1,
          mastery: Mastery.secure,
          masteryBefore: Mastery.notStarted,
          review: const [
            ReviewItem(text: 'What is 2 + 2?', verdict: Verdict.correct),
          ],
          weakLevels: const [],
          topicName: 'Number and place value',
          subject: 'Mathematics',
          next: const NextUnit(id: 'u2', name: 'Operations'),
        ),
      );
    }
    if (tries == 1) {
      return const AnswerOutcome(
        settled: false,
        verdict: Verdict.incorrect,
        feedback: 'Count on from two.',
        triesLeft: 1,
      );
    }
    return const AnswerOutcome(
      settled: true,
      verdict: Verdict.incorrect,
      feedback: 'Not this time.',
      correctAnswer: '4',
      done: true,
      result: QuizResult(
        percent: 0,
        correct: 0,
        total: 1,
        mastery: Mastery.emerging,
        review: [
          ReviewItem(
            text: 'What is 2 + 2?',
            verdict: Verdict.incorrect,
            yourAnswer: 'wrong',
            correctAnswer: '4',
          ),
        ],
        weakLevels: ['Foundations'],
        topicName: 'Number and place value',
        subject: 'Mathematics',
        askTutor: 'Can you help me understand Number and place value?',
      ),
    );
  }

  @override
  Future<Progress> getProgress(String learnerId) async {
    progressFetches++;
    return progress[learnerId] ?? Progress(studentId: learnerId);
  }

  @override
  Future<List<ChildProgress>> getAllProgress() async => [
    for (final l in me.learners)
      ChildProgress(
        name: l.name,
        grade: l.grade,
        progress: progress[l.id] ?? Progress(studentId: l.id),
      ),
  ];

  /// The learner, topic and voice flag of the most recent question.
  String? askedBy;
  String? askedTopic;
  bool askedAloud = false;

  @override
  Future<String> transcribeAudio(File audio, {String? learnerId}) async =>
      heard;

  @override
  Future<Uint8List> speak(String text, {String? learnerId}) async {
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
    String? learnerId,
    String? topic,
    bool spoken = false,
  }) async {
    asked.add(question);
    askedBy = learnerId;
    askedTopic = topic;
    askedAloud = spoken;
    return ChatResponse(
      award: award,
      answer:
          'Great question! Before we start, what do you already know about **fractions**?\n\n'
          'Think of a pizza cut into 8 equal slices. If you eat 3 slices, what fraction did you eat?',
      citations: [
        ChatCitation(
          indicatorCode: 'B4.1.3.1.1',
          strand: 'Number',
          substrand: 'Fractions',
          images: citationImages,
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
  var recordingsStopped = 0;

  @override
  Future<bool> startRecording() async {
    if (micAllowed) recordings++;
    return micAllowed;
  }

  @override
  Future<File?> stopRecording() async {
    recordingsStopped++;
    return File('/tmp/fake-question.m4a');
  }

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
  ActivityTracker? activity,
  LearnerPhotos? photos,
  ProgressStore? progressStore,
  AuthStatus status = AuthStatus.authenticated,
}) async {
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical at 3x
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final fake = api ?? FakeApi(me: me ?? parentMe);
  final tracker = activity ?? ActivityTracker();
  final auth = AuthState(api: fake)
    ..debugSet(status: status, me: me ?? fake.me);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: fake),
        Provider<VoiceService>.value(value: voice ?? FakeVoice()),
        ChangeNotifierProvider<LearnerPhotos>.value(
          value: photos ?? LearnerPhotos(),
        ),
        ChangeNotifierProvider<ActivityTracker>.value(value: tracker),
        ChangeNotifierProvider<ProgressStore>.value(
          value: progressStore ?? ProgressStore(api: fake, activity: tracker),
        ),
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

BadgeInfo _badge(
  String code,
  String name,
  String what, {
  bool earned = false,
}) => BadgeInfo(
  code: code,
  name: name,
  description: what,
  earned: earned,
  earnedAt: earned ? DateTime.utc(2026, 10, 15, 9) : null,
);

/// Ama after a good week: level 2, a 3-day streak, 12 questions in Maths and Science.
Progress amaProgress({String id = 'l-ama'}) => Progress(
  studentId: id,
  xp: 120,
  level: 2,
  levelStartXp: 50,
  nextLevelXp: 200,
  streak: 3,
  bestStreak: 3,
  questions: 12,
  photos: 1,
  voices: 2,
  lastSubject: 'Mathematics',
  lastTopic: 'Number: Fractions',
  lastActiveAt: DateTime.utc(2026, 10, 16, 8, 30),
  bySubject: const {'Mathematics': 8, 'Science': 4},
  days: const ['2026-10-14', '2026-10-15', '2026-10-16'],
  // 10 Oct 2026 is a Saturday, so the week reads Sat Sun Mon Tue Wed Thu Fri.
  week: const [
    WeekDay(day: '2026-10-10', count: 0, xp: 0),
    WeekDay(day: '2026-10-11', count: 2, xp: 20),
    WeekDay(day: '2026-10-12', count: 0, xp: 0),
    WeekDay(day: '2026-10-13', count: 1, xp: 10),
    WeekDay(day: '2026-10-14', count: 3, xp: 40),
    WeekDay(day: '2026-10-15', count: 2, xp: 20),
    WeekDay(day: '2026-10-16', count: 4, xp: 30),
  ],
  questionsThisWeek: 12,
  xpThisWeek: 120,
  recentTopics: [
    RecentTopic(
      subject: 'Mathematics',
      topic: 'Number: Fractions',
      at: DateTime.utc(2026, 10, 16, 8, 30),
    ),
    RecentTopic(
      subject: 'Science',
      topic: 'Parts of a Plant',
      at: DateTime.utc(2026, 10, 15, 16),
    ),
  ],
  badges: [
    _badge(
      'first_question',
      'First Steps',
      'Ask your very first question',
      earned: true,
    ),
    _badge('questions_10', 'Curious Mind', 'Ask 10 questions', earned: true),
    _badge('questions_50', 'Question Machine', 'Ask 50 questions'),
    _badge('streak_3', 'On a Roll', 'Learn 3 days in a row', earned: true),
    _badge('streak_7', 'Week Warrior', 'Learn 7 days in a row'),
    _badge(
      'photo_homework',
      'Snap and Solve',
      'Get help with a homework photo',
      earned: true,
    ),
    _badge(
      'voice_question',
      'Speak Up',
      'Ask a question out loud',
      earned: true,
    ),
    _badge('explorer', 'Explorer', 'Learn in 3 different subjects'),
  ],
);
