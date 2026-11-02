import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import {
  MasteryState,
  Prisma,
  QuestionLevel,
  QuizMode,
  Verdict,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ProgressService } from '../progress/progress.service';
import { loadQuizBank } from './quiz-bank.loader';
import { QuizMarker } from './quiz-marker.service';
import {
  CHECK_QUESTIONS,
  MASTERY_LABEL,
  MAX_TRIES,
  MIN_ASSIGNMENT_CHARS,
  assignmentXp,
  nextMastery,
  pointsFor,
  quizXp,
  recommended,
  scoreOf,
  summarise,
} from './quiz-rules';

const RESUME_WITHIN_MS = 24 * 60 * 60 * 1000;
const NO_PRIOR = /^entry diagnostic/i;
// A reference answer like "Use the place-value names..." is guidance, not an answer to show.
const GUIDANCE =
  /^(use|explain|describe|show|identify|give|write|state|compare|apply|discuss|list)\b/i;

const LEVEL_LABEL: Record<QuestionLevel, string> = {
  FOUNDATIONAL: 'Foundations',
  UNDERSTANDING: 'Understanding',
  APPLICATION: 'Applying it',
  REASONING: 'Reasoning',
  TRANSFER: 'New situations',
};

type QuestionRow = Prisma.QuizQuestionGetPayload<object>;

@Injectable()
export class QuizService implements OnModuleInit {
  private readonly logger = new Logger(QuizService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly progress: ProgressService,
    private readonly marker: QuizMarker,
  ) {}

  /** A fresh database has no practice units; load them from the bundled bank on first start. */
  async onModuleInit() {
    try {
      if ((await this.prisma.quizTopic.count()) > 0) return;
      const r = await loadQuizBank(this.prisma);
      this.logger.log(
        `Loaded ${r.topics} practice units (${r.questions} questions)`,
      );
    } catch (e) {
      this.logger.warn(`Could not load the practice units: ${String(e)}`);
    }
  }

  // ---- Lookups --------------------------------------------------------------------------

  private async ownStudent(userId: string, studentId: string) {
    await this.progress.requireOwned(userId, studentId);
    const student = await this.prisma.student.findUniqueOrThrow({
      where: { id: studentId },
      select: { id: true, grade: true, name: true },
    });
    if (!student.grade) {
      throw new BadRequestException('Choose a class for this learner first');
    }
    return { id: student.id, name: student.name, grade: student.grade };
  }

  /** A unit, only if it belongs to the learner's own class. */
  private async unitFor(grade: string, topicId: string) {
    const topic = await this.prisma.quizTopic.findUnique({
      where: { id: topicId },
    });
    if (!topic || topic.grade !== grade) {
      throw new NotFoundException('Practice unit not found');
    }
    return topic;
  }

  // ---- Unit lists -----------------------------------------------------------------------

  /** The units for a learner's class and one subject, with how they are getting on. */
  async topics(userId: string, studentId: string, subject: string) {
    const student = await this.ownStudent(userId, studentId);
    const units = await this.prisma.quizTopic.findMany({
      where: { grade: student.grade, subject },
      orderBy: { order: 'asc' },
    });
    if (units.length === 0) {
      throw new NotFoundException('No practice units for this subject');
    }
    const ids = units.map((u) => u.id);
    const [mastery, checks, submissions] = await Promise.all([
      this.prisma.topicMastery.findMany({
        where: { studentId, topicId: { in: ids } },
      }),
      this.prisma.quizAttempt.groupBy({
        by: ['topicId'],
        where: {
          studentId,
          topicId: { in: ids },
          mode: 'CHECK',
          finishedAt: { not: null },
        },
        _count: { _all: true },
      }),
      this.prisma.assignmentSubmission.findMany({
        where: { studentId, topicId: { in: ids } },
        select: { topicId: true, verdict: true },
      }),
    ]);
    const masteryOf = new Map(mastery.map((m) => [m.topicId, m]));
    const checked = new Set(checks.map((c) => c.topicId));
    const assignment = new Map<string, Verdict>();
    for (const s of submissions) {
      const best = assignment.get(s.topicId);
      if (!best || rank(s.verdict) > rank(best))
        assignment.set(s.topicId, s.verdict);
    }

    const recommendedId = recommended(
      units.map((u) => ({ id: u.id, state: masteryOf.get(u.id)?.state })),
    );
    const list = units.map((u) => {
      const m = masteryOf.get(u.id);
      return {
        id: u.id,
        name: u.name,
        strand: u.strand,
        term: u.term,
        week: u.week,
        order: u.order,
        state: m?.state ?? 'NOT_STARTED',
        stateLabel: MASTERY_LABEL[m?.state ?? 'NOT_STARTED'],
        bestScore: m?.bestScore ?? null,
        attempts: m?.attempts ?? 0,
        checked: checked.has(u.id),
        assignment: assignment.get(u.id) ?? null,
        recommended: u.id === recommendedId,
      };
    });
    return {
      subject,
      grade: student.grade,
      summary: summarise(
        list.map((u) => u.state as MasteryState | 'NOT_STARTED'),
      ),
      units: list,
    };
  }

  /** Mastery across every subject, for the Progress tab and the parent's view. */
  async overview(userId: string, studentId?: string) {
    const students = studentId
      ? [await this.ownStudent(userId, studentId)]
      : await this.prisma.student
          .findMany({
            where: { userId, grade: { not: null } },
            orderBy: { createdAt: 'asc' },
            select: { id: true, name: true, grade: true },
          })
          .then((rows) =>
            rows.map((s) => ({ id: s.id, name: s.name, grade: s.grade! })),
          );
    return Promise.all(students.map((s) => this.overviewFor(s)));
  }

  private async overviewFor(student: {
    id: string;
    name: string;
    grade: string;
  }) {
    const [units, mastery, open] = await Promise.all([
      this.prisma.quizTopic.findMany({
        where: { grade: student.grade as never },
        orderBy: [{ subject: 'asc' }, { order: 'asc' }],
        select: { id: true, subject: true, name: true, order: true },
      }),
      this.prisma.topicMastery.findMany({ where: { studentId: student.id } }),
      this.prisma.quizAttempt.findFirst({
        where: {
          studentId: student.id,
          finishedAt: null,
          startedAt: { gte: new Date(Date.now() - RESUME_WITHIN_MS) },
        },
        orderBy: { startedAt: 'desc' },
        include: {
          topic: { select: { id: true, name: true, subject: true } },
          answers: { where: { settled: true }, select: { id: true } },
        },
      }),
    ]);
    const masteryOf = new Map(mastery.map((m) => [m.topicId, m]));
    const subjects = new Map<string, typeof units>();
    for (const u of units) {
      subjects.set(u.subject, [...(subjects.get(u.subject) ?? []), u]);
    }
    const bySubject = [...subjects.entries()].map(([subject, list]) => {
      const states = list.map(
        (u) => masteryOf.get(u.id)?.state ?? 'NOT_STARTED',
      );
      const scored = list
        .map((u) => masteryOf.get(u.id)?.bestScore)
        .filter((s): s is number => s !== undefined);
      return {
        subject,
        ...summarise(states),
        averageScore: scored.length
          ? Math.round(
              (scored.reduce((a, b) => a + b, 0) / scored.length) * 100,
            ) / 100
          : null,
      };
    });
    const needsRevision = units
      .filter((u) => {
        const s = masteryOf.get(u.id)?.state;
        return s === 'NEEDS_REVISION' || s === 'EMERGING';
      })
      .slice(0, 6)
      .map((u) => ({
        topicId: u.id,
        subject: u.subject,
        name: u.name,
        state: masteryOf.get(u.id)!.state,
        stateLabel: MASTERY_LABEL[masteryOf.get(u.id)!.state],
      }));
    const totals = summarise(
      units.map((u) => masteryOf.get(u.id)?.state ?? 'NOT_STARTED'),
    );
    return {
      studentId: student.id,
      name: student.name,
      grade: student.grade,
      ...totals,
      bySubject,
      needsRevision,
      // A quiz or quick check left half done, for "carry on" on the home screen.
      unfinished: open
        ? {
            attemptId: open.id,
            topicId: open.topic.id,
            topicName: open.topic.name,
            subject: open.topic.subject,
            mode: open.mode,
            answered: open.answers.length,
            total: open.mode === 'CHECK' ? CHECK_QUESTIONS : 5,
            startedAt: open.startedAt,
          }
        : null,
    };
  }

  // ---- Attempts -------------------------------------------------------------------------

  private questionsFor(
    topicId: string,
    mode: QuizMode,
  ): Prisma.QuizQuestionFindManyArgs {
    return {
      where: { topicId, ...(mode === 'CHECK' ? { diagnostic: true } : {}) },
      orderBy: { order: 'asc' },
      take: mode === 'CHECK' ? CHECK_QUESTIONS : undefined,
    };
  }

  /** Start a quiz or quick check, or carry on the one the learner left unfinished. */
  async start(
    userId: string,
    dto: { studentId: string; topicId: string; mode: QuizMode },
  ) {
    const student = await this.ownStudent(userId, dto.studentId);
    const topic = await this.unitFor(student.grade, dto.topicId);

    const open = await this.prisma.quizAttempt.findFirst({
      where: {
        studentId: student.id,
        topicId: topic.id,
        mode: dto.mode,
        finishedAt: null,
        startedAt: { gte: new Date(Date.now() - RESUME_WITHIN_MS) },
      },
      orderBy: { startedAt: 'desc' },
    });
    const attempt =
      open ??
      (await this.prisma.quizAttempt.create({
        data: { studentId: student.id, topicId: topic.id, mode: dto.mode },
      }));
    return this.view(attempt.id, student.id);
  }

  async get(userId: string, attemptId: string) {
    const attempt = await this.ownAttempt(userId, attemptId);
    return this.view(attempt.id, attempt.studentId);
  }

  private async ownAttempt(userId: string, attemptId: string) {
    const attempt = await this.prisma.quizAttempt.findFirst({
      where: { id: attemptId, student: { userId } },
    });
    if (!attempt) throw new NotFoundException('Quiz not found');
    return attempt;
  }

  /** What the app needs to show (or resume) an attempt. Never includes the answers. */
  private async view(attemptId: string, studentId: string) {
    const attempt = await this.prisma.quizAttempt.findUniqueOrThrow({
      where: { id: attemptId },
      include: { topic: true, answers: true },
    });
    const questions = await this.prisma.quizQuestion.findMany(
      this.questionsFor(attempt.topicId, attempt.mode),
    );
    const byQuestion = new Map(attempt.answers.map((a) => [a.questionId, a]));
    return {
      attemptId: attempt.id,
      studentId,
      mode: attempt.mode,
      finished: attempt.finishedAt !== null,
      topic: {
        id: attempt.topic.id,
        name: attempt.topic.name,
        subject: attempt.topic.subject,
      },
      total: questions.length,
      questions: questions.map((q) => {
        const a = byQuestion.get(q.id);
        return {
          id: q.id,
          order: q.order,
          level: q.level,
          levelLabel: LEVEL_LABEL[q.level],
          text: q.question,
          // Set once the learner has had a go at it.
          tries: a?.tries ?? 0,
          settled: a?.settled ?? false,
          ...(a?.settled ? this.reveal(q, a) : {}),
          ...(a && !a.settled
            ? { verdict: a.verdict, feedback: a.feedback, yourAnswer: a.answer }
            : {}),
        };
      }),
      ...(attempt.finishedAt
        ? { result: await this.resultFor(attempt.id) }
        : {}),
    };
  }

  private reveal(
    q: QuestionRow,
    a: { answer: string; verdict: Verdict; feedback: string; points: number },
  ) {
    return {
      yourAnswer: a.answer,
      verdict: a.verdict,
      points: a.points,
      feedback: a.feedback,
      // Shown when it helps: never for a right answer, never for pure guidance.
      correctAnswer:
        a.verdict !== 'CORRECT' && !GUIDANCE.test(q.expectedAnswer.trim())
          ? q.expectedAnswer
          : null,
      workedSolution:
        a.verdict !== 'CORRECT' && q.workedSolution ? q.workedSolution : null,
    };
  }

  /** Mark one answer. The first wrong try gets a nudge and a second go; after that, or when
   *  right, the question is done. The last question done finishes the attempt. */
  async answer(
    userId: string,
    attemptId: string,
    dto: { questionId: string; answer: string },
  ) {
    const attempt = await this.ownAttempt(userId, attemptId);
    if (attempt.finishedAt)
      throw new ConflictException('This quiz is finished');
    const student = await this.ownStudent(userId, attempt.studentId);

    const questions = await this.prisma.quizQuestion.findMany(
      this.questionsFor(attempt.topicId, attempt.mode),
    );
    const question = questions.find((q) => q.id === dto.questionId);
    if (!question)
      throw new NotFoundException('Question not found in this quiz');
    const topic = await this.prisma.quizTopic.findUniqueOrThrow({
      where: { id: attempt.topicId },
    });

    const existing = await this.prisma.quizAnswer.findUnique({
      where: {
        attemptId_questionId: { attemptId, questionId: question.id },
      },
    });
    if (existing?.settled) throw new ConflictException('Already answered');
    const tries = existing ? existing.tries + 1 : 1;

    const marked = await this.marker.markAnswer({
      studentId: student.id,
      grade: student.grade,
      subject: topic.subject,
      question: question.question,
      expected: question.expectedAnswer,
      rubric: question.rubric,
      answer: dto.answer,
      firstTry: tries === 1,
    });
    const settled = marked.verdict === 'CORRECT' || tries >= MAX_TRIES;
    const points = settled ? pointsFor(marked.verdict, tries) : 0;
    const row = {
      answer: dto.answer,
      tries,
      verdict: marked.verdict,
      points,
      feedback: marked.feedback,
      aiGraded: marked.ai,
      settled,
    };
    await this.prisma.quizAnswer.upsert({
      where: { attemptId_questionId: { attemptId, questionId: question.id } },
      create: { attemptId, questionId: question.id, ...row },
      update: row,
    });

    if (!settled) {
      return {
        questionId: question.id,
        settled: false,
        triesLeft: MAX_TRIES - tries,
        verdict: marked.verdict,
        feedback: marked.feedback,
      };
    }

    const answered = await this.prisma.quizAnswer.count({
      where: { attemptId, settled: true },
    });
    const done = answered >= questions.length;
    return {
      questionId: question.id,
      settled: true,
      done,
      ...this.reveal(question, row),
      ...(done ? { result: await this.finish(attempt.id) } : {}),
    };
  }

  // ---- Finishing ------------------------------------------------------------------------

  /** Score the attempt, move the unit's mastery, pay XP. */
  private async finish(attemptId: string) {
    const attempt = await this.prisma.quizAttempt.findUniqueOrThrow({
      where: { id: attemptId },
      include: { topic: true, answers: { include: { question: true } } },
    });
    if (attempt.finishedAt) return this.resultFor(attemptId);

    const score = scoreOf(attempt.answers.map((a) => a.points));
    const transferCorrect = attempt.answers.some(
      (a) => a.question.level === 'TRANSFER' && a.verdict === 'CORRECT',
    );
    const perfect =
      attempt.mode === 'QUIZ' &&
      attempt.answers.length > 0 &&
      attempt.answers.every((a) => a.points === 1);

    const previous = await this.prisma.quizAttempt.aggregate({
      where: {
        studentId: attempt.studentId,
        topicId: attempt.topicId,
        mode: attempt.mode,
        finishedAt: { not: null },
        id: { not: attemptId },
      },
      _max: { score: true },
    });
    const xpBase = quizXp(attempt.mode, score, previous._max.score);

    const before = await this.prisma.topicMastery.findUnique({
      where: {
        studentId_topicId: {
          studentId: attempt.studentId,
          topicId: attempt.topicId,
        },
      },
    });
    const after = nextMastery(before, {
      mode: attempt.mode,
      score,
      transferCorrect,
    });
    const isQuiz = attempt.mode === 'QUIZ';
    await this.prisma.$transaction([
      this.prisma.quizAttempt.update({
        where: { id: attemptId },
        data: { finishedAt: new Date(), score },
      }),
      this.prisma.topicMastery.upsert({
        where: {
          studentId_topicId: {
            studentId: attempt.studentId,
            topicId: attempt.topicId,
          },
        },
        create: {
          studentId: attempt.studentId,
          topicId: attempt.topicId,
          state: after.state,
          attempts: isQuiz ? 1 : 0,
          bestScore: isQuiz ? score : 0,
          lastScore: score,
          strongAttempts: after.strongAttempts,
        },
        update: {
          state: after.state,
          strongAttempts: after.strongAttempts,
          lastScore: score,
          lastAttemptAt: new Date(),
          ...(isQuiz
            ? {
                attempts: { increment: 1 },
                bestScore: Math.max(before?.bestScore ?? 0, score),
              }
            : {}),
        },
      }),
    ]);

    const progress = await this.progress.record(attempt.studentId, {
      kind: attempt.mode,
      subject: attempt.topic.subject,
      topic: attempt.topic.name,
      baseXp: xpBase,
      perfect,
    });
    await this.prisma.quizAttempt.update({
      where: { id: attemptId },
      data: { xp: progress.xpGained },
    });

    return {
      ...(await this.resultFor(attemptId)),
      progress,
      masteryBefore: before?.state ?? 'NOT_STARTED',
    };
  }

  /** The summary of a finished attempt: score, mastery, what to revise, what is next. */
  private async resultFor(attemptId: string) {
    const attempt = await this.prisma.quizAttempt.findUniqueOrThrow({
      where: { id: attemptId },
      include: {
        topic: true,
        answers: {
          include: { question: true },
          orderBy: { question: { order: 'asc' } },
        },
      },
    });
    const mastery = await this.prisma.topicMastery.findUnique({
      where: {
        studentId_topicId: {
          studentId: attempt.studentId,
          topicId: attempt.topicId,
        },
      },
    });
    const score = attempt.score ?? 0;
    const state: MasteryState | 'NOT_STARTED' = mastery?.state ?? 'NOT_STARTED';

    const missed = attempt.answers.filter((a) => a.verdict !== 'CORRECT');
    const topic = attempt.topic;
    const units = await this.prisma.quizTopic.findMany({
      where: { grade: topic.grade, subject: topic.subject },
      orderBy: { order: 'asc' },
      select: { id: true, name: true, order: true },
    });
    const mine = await this.prisma.topicMastery.findMany({
      where: {
        studentId: attempt.studentId,
        topicId: { in: units.map((u) => u.id) },
      },
      select: { topicId: true, state: true },
    });
    const stateOf = new Map(mine.map((m) => [m.topicId, m.state]));
    const nextId = recommended(
      units.map((u) => ({ id: u.id, state: stateOf.get(u.id) })),
      topic.id,
    );

    return {
      attemptId,
      mode: attempt.mode,
      topic: { id: topic.id, name: topic.name, subject: topic.subject },
      score,
      percent: Math.round(score * 100),
      xp: attempt.xp,
      mastery: { state, label: MASTERY_LABEL[state] },
      correct: attempt.answers.filter((a) => a.verdict === 'CORRECT').length,
      total: attempt.answers.length,
      review: attempt.answers.map((a) => ({
        questionId: a.questionId,
        order: a.question.order,
        level: a.question.level,
        levelLabel: LEVEL_LABEL[a.question.level],
        text: a.question.question,
        ...this.reveal(a.question, a),
      })),
      weakLevels: [
        ...new Set(missed.map((a) => LEVEL_LABEL[a.question.level])),
      ],
      // Where to go if it did not go well: the unit this one builds on, and the tutor.
      revise:
        score < 0.8
          ? {
              prerequisite: NO_PRIOR.test(topic.previousLearning)
                ? null
                : topic.previousLearning,
              askTutor: `Can you help me understand ${topic.name}?`,
            }
          : null,
      next: nextId
        ? { id: nextId, name: units.find((u) => u.id === nextId)!.name }
        : null,
    };
  }

  // ---- Assignments ----------------------------------------------------------------------

  async assignment(userId: string, studentId: string, topicId: string) {
    const student = await this.ownStudent(userId, studentId);
    const topic = await this.unitFor(student.grade, topicId);
    const last = await this.prisma.assignmentSubmission.findFirst({
      where: { studentId, topicId },
      orderBy: { createdAt: 'desc' },
    });
    return {
      topicId,
      topic: topic.name,
      subject: topic.subject,
      task: topic.assignmentTask,
      successCriteria: splitCriteria(topic.assignmentCriteria),
      reflectionPrompt: topic.assignmentReflection,
      minChars: MIN_ASSIGNMENT_CHARS,
      last: last && {
        verdict: last.verdict,
        feedback: last.feedback,
        response: last.response,
        reflection: last.reflection,
        at: last.createdAt,
      },
    };
  }

  async submitAssignment(
    userId: string,
    topicId: string,
    dto: { studentId: string; response: string; reflection?: string },
  ) {
    const student = await this.ownStudent(userId, dto.studentId);
    const topic = await this.unitFor(student.grade, topicId);
    const response = dto.response.trim();
    if (response.length < MIN_ASSIGNMENT_CHARS) {
      throw new BadRequestException(
        `Write a little more, at least ${MIN_ASSIGNMENT_CHARS} characters, so your work can be checked.`,
      );
    }
    const reflection = (dto.reflection ?? '').trim();

    const marked = await this.marker.markAssignment({
      studentId: student.id,
      grade: student.grade,
      subject: topic.subject,
      task: topic.assignmentTask,
      criteria: topic.assignmentCriteria,
      response,
      reflection,
    });
    // Without the marker a real attempt is still credited, modestly, rather than turned away.
    const verdict: Verdict = marked?.verdict ?? 'PARTIAL';
    const feedback =
      marked?.feedback ||
      'Thank you for handing this in. Keep going: check each step against the success criteria.';

    const earlier = await this.prisma.assignmentSubmission.aggregate({
      where: { studentId: student.id, topicId },
      _max: { xp: true },
    });
    const xpBase = assignmentXp(verdict, earlier._max.xp ?? 0);
    const progress = await this.progress.record(student.id, {
      kind: 'ASSIGNMENT',
      subject: topic.subject,
      topic: topic.name,
      baseXp: xpBase,
    });
    await this.prisma.assignmentSubmission.create({
      data: {
        studentId: student.id,
        topicId,
        response,
        reflection,
        verdict,
        feedback,
        xp: progress.xpGained,
      },
    });
    return {
      verdict,
      feedback,
      xp: progress.xpGained,
      progress: progress,
    };
  }
}

// ---- Helpers --------------------------------------------------------------------------

function rank(v: Verdict): number {
  return v === 'CORRECT' ? 2 : v === 'PARTIAL' ? 1 : 0;
}

function splitCriteria(text: string): string[] {
  return text
    .split(/;\s*/)
    .map((s) => s.trim().replace(/\.$/, ''))
    .filter(Boolean);
}
