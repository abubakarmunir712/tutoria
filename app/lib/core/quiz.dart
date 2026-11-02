import 'package:flutter/material.dart';

import 'design/design.dart';
import 'progress.dart';

/// Where a learner stands on a practice unit (the progression map's states).
enum Mastery {
  notStarted('NOT_STARTED', 'Not started'),
  emerging('EMERGING', 'Emerging'),
  developing('DEVELOPING', 'Developing'),
  secure('SECURE', 'Secure'),
  mastered('MASTERED', 'Mastered'),
  needsRevision('NEEDS_REVISION', 'Needs revision');

  const Mastery(this.api, this.label);
  final String api;
  final String label;

  static Mastery parse(String? value) => Mastery.values.firstWhere(
    (m) => m.api == value,
    orElse: () => Mastery.notStarted,
  );

  Color get color => switch (this) {
    notStarted => TColors.faint,
    emerging => TColors.warning,
    developing => TColors.blue600,
    secure => TColors.success,
    mastered => const Color(0xFF8B4DE8),
    needsRevision => TColors.danger,
  };

  Color get tint => switch (this) {
    notStarted => TColors.blue50,
    emerging => TColors.socialTint,
    developing => TColors.blue100,
    secure => TColors.scienceTint,
    mastered => TColors.computingTint,
    needsRevision => TColors.dangerTint,
  };

  IconData get icon => switch (this) {
    notStarted => Icons.radio_button_unchecked_rounded,
    emerging => Icons.eco_rounded,
    developing => Icons.trending_up_rounded,
    secure => Icons.check_circle_rounded,
    mastered => Icons.workspace_premium_rounded,
    needsRevision => Icons.refresh_rounded,
  };
}

/// How well a written answer or assignment went.
enum Verdict {
  correct,
  partial,
  incorrect;

  static Verdict parse(String? value) => switch (value) {
    'CORRECT' => correct,
    'PARTIAL' => partial,
    _ => incorrect,
  };
}

/// One practice unit in a subject's list.
@immutable
class PracticeUnit {
  const PracticeUnit({
    required this.id,
    required this.name,
    required this.strand,
    required this.order,
    required this.mastery,
    this.bestScore,
    this.attempts = 0,
    this.checked = false,
    this.assignment,
    this.recommended = false,
  });

  factory PracticeUnit.fromJson(Map<String, dynamic> json) => PracticeUnit(
    id: json['id'] as String,
    name: json['name'] as String,
    strand: json['strand'] as String? ?? '',
    order: json['order'] as int? ?? 0,
    mastery: Mastery.parse(json['state'] as String?),
    bestScore: (json['bestScore'] as num?)?.toDouble(),
    attempts: json['attempts'] as int? ?? 0,
    checked: json['checked'] as bool? ?? false,
    assignment: json['assignment'] == null
        ? null
        : Verdict.parse(json['assignment'] as String?),
    recommended: json['recommended'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String strand;
  final int order;
  final Mastery mastery;
  final double? bestScore;
  final int attempts;

  /// Whether the quick check has been done.
  final bool checked;

  /// The best assignment result so far, if any was handed in.
  final Verdict? assignment;

  /// The unit to do next.
  final bool recommended;

  int? get bestPercent => bestScore == null ? null : (bestScore! * 100).round();
}

/// Counts of units by where the learner is, for a subject or everything.
@immutable
class MasterySummary {
  const MasterySummary({
    this.total = 0,
    this.started = 0,
    this.mastered = 0,
    this.secure = 0,
    this.developing = 0,
    this.needsRevision = 0,
  });

  factory MasterySummary.fromJson(Map<String, dynamic> json) => MasterySummary(
    total: json['total'] as int? ?? 0,
    started: json['started'] as int? ?? 0,
    mastered: json['mastered'] as int? ?? 0,
    secure: json['secure'] as int? ?? 0,
    developing: json['developing'] as int? ?? 0,
    needsRevision: json['needsRevision'] as int? ?? 0,
  );

  final int total;
  final int started;
  final int mastered;
  final int secure;
  final int developing;
  final int needsRevision;

  /// Units the learner has got to Secure or better.
  int get done => secure + mastered;

  double get fraction => total == 0 ? 0 : done / total;
}

@immutable
class PracticeList {
  const PracticeList({
    required this.subject,
    required this.summary,
    required this.units,
  });

  factory PracticeList.fromJson(Map<String, dynamic> json) => PracticeList(
    subject: json['subject'] as String,
    summary: MasterySummary.fromJson(json['summary'] as Map<String, dynamic>),
    units: (json['units'] as List)
        .map((u) => PracticeUnit.fromJson(u as Map<String, dynamic>))
        .toList(),
  );

  final String subject;
  final MasterySummary summary;
  final List<PracticeUnit> units;
}

@immutable
class SubjectMastery {
  const SubjectMastery({
    required this.subject,
    required this.summary,
    this.averageScore,
  });

  factory SubjectMastery.fromJson(Map<String, dynamic> json) => SubjectMastery(
    subject: json['subject'] as String,
    summary: MasterySummary.fromJson(json),
    averageScore: (json['averageScore'] as num?)?.toDouble(),
  );

  final String subject;
  final MasterySummary summary;
  final double? averageScore;
}

@immutable
class UnitToRevise {
  const UnitToRevise({
    required this.topicId,
    required this.subject,
    required this.name,
    required this.mastery,
  });

  factory UnitToRevise.fromJson(Map<String, dynamic> json) => UnitToRevise(
    topicId: json['topicId'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
    mastery: Mastery.parse(json['state'] as String?),
  );

  final String topicId;
  final String subject;
  final String name;
  final Mastery mastery;
}

/// Mastery across every subject for one learner (Progress tab and the parent's view).
@immutable
class MasteryOverview {
  const MasteryOverview({
    required this.studentId,
    required this.summary,
    required this.bySubject,
    required this.needsRevision,
  });

  factory MasteryOverview.fromJson(Map<String, dynamic> json) =>
      MasteryOverview(
        studentId: json['studentId'] as String,
        summary: MasterySummary.fromJson(json),
        bySubject: ((json['bySubject'] as List?) ?? const [])
            .map((s) => SubjectMastery.fromJson(s as Map<String, dynamic>))
            .toList(),
        needsRevision: ((json['needsRevision'] as List?) ?? const [])
            .map((s) => UnitToRevise.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final String studentId;
  final MasterySummary summary;
  final List<SubjectMastery> bySubject;
  final List<UnitToRevise> needsRevision;
}

/// One question in a quiz, with what happened so far if the learner already had a go.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.order,
    required this.levelLabel,
    required this.text,
    this.settled = false,
    this.yourAnswer,
    this.verdict,
    this.feedback,
    this.correctAnswer,
    this.workedSolution,
    this.tries = 0,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String,
    order: json['order'] as int? ?? 0,
    levelLabel: json['levelLabel'] as String? ?? '',
    text: json['text'] as String,
    settled: json['settled'] as bool? ?? false,
    yourAnswer: json['yourAnswer'] as String?,
    verdict: json['verdict'] == null
        ? null
        : Verdict.parse(json['verdict'] as String?),
    feedback: json['feedback'] as String?,
    correctAnswer: json['correctAnswer'] as String?,
    workedSolution: json['workedSolution'] as String?,
    tries: json['tries'] as int? ?? 0,
  );

  final String id;
  final int order;
  final String levelLabel;
  final String text;
  final bool settled;
  final String? yourAnswer;
  final Verdict? verdict;
  final String? feedback;
  final String? correctAnswer;
  final String? workedSolution;
  final int tries;
}

/// A quiz (or quick check) in progress, as the server holds it.
@immutable
class QuizAttempt {
  const QuizAttempt({
    required this.attemptId,
    required this.isCheck,
    required this.topicId,
    required this.topicName,
    required this.subject,
    required this.questions,
    this.result,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final topic = json['topic'] as Map<String, dynamic>;
    return QuizAttempt(
      attemptId: json['attemptId'] as String,
      isCheck: json['mode'] == 'CHECK',
      topicId: topic['id'] as String,
      topicName: topic['name'] as String,
      subject: topic['subject'] as String,
      questions: (json['questions'] as List)
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      result: json['result'] == null
          ? null
          : QuizResult.fromJson(json['result'] as Map<String, dynamic>),
    );
  }

  final String attemptId;
  final bool isCheck;
  final String topicId;
  final String topicName;
  final String subject;
  final List<QuizQuestion> questions;
  final QuizResult? result;

  /// Index of the first question not yet done.
  int get firstOpen {
    final i = questions.indexWhere((q) => !q.settled);
    return i < 0 ? questions.length : i;
  }
}

/// The outcome of sending one answer.
@immutable
class AnswerOutcome {
  const AnswerOutcome({
    required this.settled,
    required this.verdict,
    required this.feedback,
    this.triesLeft = 0,
    this.correctAnswer,
    this.workedSolution,
    this.done = false,
    this.result,
  });

  factory AnswerOutcome.fromJson(Map<String, dynamic> json) => AnswerOutcome(
    settled: json['settled'] as bool? ?? false,
    verdict: Verdict.parse(json['verdict'] as String?),
    feedback: json['feedback'] as String? ?? '',
    triesLeft: json['triesLeft'] as int? ?? 0,
    correctAnswer: json['correctAnswer'] as String?,
    workedSolution: json['workedSolution'] as String?,
    done: json['done'] as bool? ?? false,
    result: json['result'] == null
        ? null
        : QuizResult.fromJson(json['result'] as Map<String, dynamic>),
  );

  /// False after a wrong first try: the learner may answer again.
  final bool settled;
  final Verdict verdict;
  final String feedback;
  final int triesLeft;
  final String? correctAnswer;
  final String? workedSolution;
  final bool done;
  final QuizResult? result;
}

@immutable
class ReviewItem {
  const ReviewItem({
    required this.text,
    required this.verdict,
    this.yourAnswer,
    this.correctAnswer,
    this.workedSolution,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
    text: json['text'] as String,
    verdict: Verdict.parse(json['verdict'] as String?),
    yourAnswer: json['yourAnswer'] as String?,
    correctAnswer: json['correctAnswer'] as String?,
    workedSolution: json['workedSolution'] as String?,
  );

  final String text;
  final Verdict verdict;
  final String? yourAnswer;
  final String? correctAnswer;
  final String? workedSolution;
}

@immutable
class NextUnit {
  const NextUnit({required this.id, required this.name});
  final String id;
  final String name;
}

/// What a finished quiz or quick check came to.
@immutable
class QuizResult {
  const QuizResult({
    required this.percent,
    required this.correct,
    required this.total,
    required this.mastery,
    required this.review,
    required this.weakLevels,
    required this.topicName,
    required this.subject,
    this.prerequisite,
    this.askTutor,
    this.next,
    this.award,
    this.masteryBefore,
    this.isCheck = false,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    final topic = json['topic'] as Map<String, dynamic>;
    final revise = json['revise'] as Map<String, dynamic>?;
    final next = json['next'] as Map<String, dynamic>?;
    return QuizResult(
      percent: json['percent'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      mastery: Mastery.parse((json['mastery'] as Map)['state'] as String?),
      masteryBefore: json['masteryBefore'] == null
          ? null
          : Mastery.parse(json['masteryBefore'] as String?),
      review: ((json['review'] as List?) ?? const [])
          .map((r) => ReviewItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      weakLevels: ((json['weakLevels'] as List?) ?? const []).cast<String>(),
      topicName: topic['name'] as String,
      subject: topic['subject'] as String,
      prerequisite: revise?['prerequisite'] as String?,
      askTutor: revise?['askTutor'] as String?,
      next: next == null
          ? null
          : NextUnit(id: next['id'] as String, name: next['name'] as String),
      award: json['progress'] is Map<String, dynamic>
          ? Award.fromJson(json['progress'] as Map<String, dynamic>)
          : null,
      isCheck: json['mode'] == 'CHECK',
    );
  }

  final int percent;
  final int correct;
  final int total;
  final Mastery mastery;
  final Mastery? masteryBefore;
  final List<ReviewItem> review;
  final List<String> weakLevels;
  final String topicName;
  final String subject;

  /// The unit this one builds on, when it is worth going back to.
  final String? prerequisite;

  /// A question to open the tutor with.
  final String? askTutor;
  final NextUnit? next;

  /// XP, level and badges the quiz earned (only on the response that finished it).
  final Award? award;
  final bool isCheck;
}

@immutable
class AssignmentInfo {
  const AssignmentInfo({
    required this.topicName,
    required this.subject,
    required this.task,
    required this.criteria,
    required this.reflectionPrompt,
    required this.minChars,
    this.lastVerdict,
    this.lastFeedback,
  });

  factory AssignmentInfo.fromJson(Map<String, dynamic> json) {
    final last = json['last'] as Map<String, dynamic>?;
    return AssignmentInfo(
      topicName: json['topic'] as String,
      subject: json['subject'] as String,
      task: json['task'] as String,
      criteria: (json['successCriteria'] as List).cast<String>(),
      reflectionPrompt: json['reflectionPrompt'] as String? ?? '',
      minChars: json['minChars'] as int? ?? 40,
      lastVerdict: last == null
          ? null
          : Verdict.parse(last['verdict'] as String?),
      lastFeedback: last?['feedback'] as String?,
    );
  }

  final String topicName;
  final String subject;
  final String task;
  final List<String> criteria;
  final String reflectionPrompt;
  final int minChars;
  final Verdict? lastVerdict;
  final String? lastFeedback;
}

@immutable
class AssignmentOutcome {
  const AssignmentOutcome({
    required this.verdict,
    required this.feedback,
    this.award,
  });

  factory AssignmentOutcome.fromJson(Map<String, dynamic> json) =>
      AssignmentOutcome(
        verdict: Verdict.parse(json['verdict'] as String?),
        feedback: json['feedback'] as String? ?? '',
        award: json['progress'] is Map<String, dynamic>
            ? Award.fromJson(json['progress'] as Map<String, dynamic>)
            : null,
      );

  final Verdict verdict;
  final String feedback;
  final Award? award;
}
