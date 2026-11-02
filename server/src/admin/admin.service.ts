import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { levelForXp, utcDayKey } from '../progress/gamification';
import { PrismaService } from '../prisma/prisma.service';
import { Limits, SettingsService } from '../usage/settings.service';
import { costAlerts } from '../usage/alerts';
import { startOfUtcDay } from '../usage/usage.service';

const DAY_MS = 24 * 60 * 60 * 1000;

/** The first instant of the UTC day `days - 1` days before `now`'s day. */
function windowStart(now: Date, days: number) {
  return new Date(startOfUtcDay(now).getTime() - (days - 1) * DAY_MS);
}

/** One entry per day in the window, filling the days with nothing in them. */
function fillDays<T extends { day: string }>(
  now: Date,
  days: number,
  rows: T[],
  empty: (day: string) => T,
): T[] {
  const byDay = new Map(rows.map((r) => [r.day, r]));
  const start = windowStart(now, days).getTime();
  return Array.from({ length: days }, (_, i) => {
    const day = utcDayKey(new Date(start + i * DAY_MS));
    return byDay.get(day) ?? empty(day);
  });
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: SettingsService,
  ) {}

  async me(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { id: true, fullName: true, email: true },
    });
  }

  /** The numbers on the dashboard's front page; the page polls this to stay live. */
  async overview(now = new Date()) {
    const today = startOfUtcDay(now);
    const week = windowStart(now, 7);
    const month = windowStart(now, 30);

    const [
      parents,
      learners,
      activeToday,
      active7d,
      active30d,
      questionsToday,
      questions7d,
      usageToday,
      usage7d,
      usage30d,
      errorsToday,
      xpTotal,
      recent,
      limits,
      quizzes7d,
      quizzesToday,
      masteredUnits,
      earlierSpend,
    ] = await Promise.all([
      this.prisma.user.count({ where: { role: 'PARENT', isAdmin: false } }),
      this.prisma.student.count(),
      this.activeLearners(today),
      this.activeLearners(week),
      this.activeLearners(month),
      this.prisma.learningEvent.count({ where: { createdAt: { gte: today } } }),
      this.prisma.learningEvent.count({ where: { createdAt: { gte: week } } }),
      this.spend(today),
      this.spend(week),
      this.spend(month),
      this.prisma.usageLog.count({
        where: { createdAt: { gte: today }, ok: false },
      }),
      this.prisma.studentStats.aggregate({ _sum: { xp: true } }),
      this.prisma.learningEvent.findMany({
        orderBy: { createdAt: 'desc' },
        take: 12,
        select: {
          id: true,
          kind: true,
          subject: true,
          topic: true,
          xp: true,
          createdAt: true,
          student: { select: { name: true, grade: true } },
        },
      }),
      this.settings.limits(),
      this.prisma.quizAttempt.aggregate({
        where: { mode: 'QUIZ', finishedAt: { gte: week } },
        _count: { _all: true },
        _avg: { score: true },
      }),
      this.prisma.quizAttempt.count({
        where: { mode: 'QUIZ', finishedAt: { gte: today } },
      }),
      this.prisma.topicMastery.count({ where: { state: 'MASTERED' } }),
      // The seven days before today, to tell a spike from a normal day.
      this.spendBetween(new Date(today.getTime() - 7 * DAY_MS), today),
    ]);

    const alerts = costAlerts({
      costToday: usageToday.cost,
      capUsd: limits.dailyCostCapUsd,
      alertPercent: limits.costAlertPercent,
      dailyAverageBefore: earlierSpend / 7,
      callsToday: usageToday.calls,
      errorsToday,
    });

    return {
      generatedAt: now,
      people: { parents, learners },
      active: {
        today: activeToday,
        last7Days: active7d,
        last30Days: active30d,
      },
      questions: { today: questionsToday, last7Days: questions7d },
      quizzes: {
        today: quizzesToday,
        last7Days: quizzes7d._count._all,
        averageScore7Days: quizzes7d._avg.score ?? null,
        masteredUnits,
      },
      alerts,
      xpAwarded: xpTotal._sum.xp ?? 0,
      cost: {
        today: usageToday.cost,
        last7Days: usage7d.cost,
        last30Days: usage30d.cost,
        callsToday: usageToday.calls,
        errorsToday,
        // A "session" is one learner's day of using the tutor.
        perSession7Days: await this.costPerSession(week),
      },
      limits: {
        ...limits,
        costTodayPercent:
          limits.dailyCostCapUsd > 0
            ? Math.min(100, (usageToday.cost / limits.dailyCostCapUsd) * 100)
            : null,
      },
      recent: recent.map((e) => ({
        id: e.id,
        kind: e.kind,
        subject: e.subject,
        topic: e.topic,
        xp: e.xp,
        at: e.createdAt,
        learner: e.student.name,
        grade: e.student.grade,
      })),
    };
  }

  /** How practice is going: quizzes taken, scores, the hardest units and the mastery spread. */
  async learning(days = 30, now = new Date()) {
    const since = windowStart(now, days);
    const [totals, daily, bySubject, hardest, mastery, assignments] =
      await Promise.all([
        this.prisma.$queryRaw<
          { quizzes: number; checks: number; learners: number; avg: number }[]
        >(Prisma.sql`
          SELECT count(*) FILTER (WHERE "mode" = 'QUIZ')::int AS quizzes,
                 count(*) FILTER (WHERE "mode" = 'CHECK')::int AS checks,
                 count(DISTINCT "studentId")::int AS learners,
                 coalesce(avg("score") FILTER (WHERE "mode" = 'QUIZ'), 0)::float AS avg
          FROM "QuizAttempt" WHERE "finishedAt" >= ${since}`),
        this.prisma.$queryRaw<{ day: string; quizzes: number; avg: number }[]>(
          Prisma.sql`
          SELECT to_char("finishedAt" AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS day,
                 count(*)::int AS quizzes, coalesce(avg("score"), 0)::float AS avg
          FROM "QuizAttempt"
          WHERE "finishedAt" >= ${since} AND "mode" = 'QUIZ' GROUP BY 1 ORDER BY 1`,
        ),
        this.prisma.$queryRaw<
          { subject: string; quizzes: number; avg: number }[]
        >(Prisma.sql`
          SELECT t."subject", count(*)::int AS quizzes, avg(a."score")::float AS avg
          FROM "QuizAttempt" a JOIN "QuizTopic" t ON t."id" = a."topicId"
          WHERE a."finishedAt" >= ${since} AND a."mode" = 'QUIZ'
          GROUP BY 1 ORDER BY 2 DESC`),
        // Units with a few attempts and the lowest average: where learners struggle most.
        this.prisma.$queryRaw<
          {
            name: string;
            subject: string;
            grade: string;
            quizzes: number;
            avg: number;
          }[]
        >(Prisma.sql`
          SELECT t."name", t."subject", t."grade"::text AS grade,
                 count(*)::int AS quizzes, avg(a."score")::float AS avg
          FROM "QuizAttempt" a JOIN "QuizTopic" t ON t."id" = a."topicId"
          WHERE a."finishedAt" >= ${since} AND a."mode" = 'QUIZ'
          GROUP BY t."id" HAVING count(*) >= 3 ORDER BY avg(a."score") ASC LIMIT 8`),
        this.prisma.topicMastery.groupBy({
          by: ['state'],
          _count: { _all: true },
        }),
        this.prisma.assignmentSubmission.groupBy({
          by: ['verdict'],
          where: { createdAt: { gte: since } },
          _count: { _all: true },
        }),
      ]);
    const t = totals[0];
    return {
      days,
      totals: {
        quizzes: t?.quizzes ?? 0,
        checks: t?.checks ?? 0,
        learners: t?.learners ?? 0,
        averageScore: t?.avg ?? 0,
        assignments: assignments.reduce((n, a) => n + a._count._all, 0),
      },
      daily: fillDays(now, days, daily, (day) => ({
        day,
        quizzes: 0,
        avg: 0,
      })),
      bySubject,
      hardest,
      mastery: mastery.map((m) => ({ state: m.state, units: m._count._all })),
    };
  }

  /** Usage patterns over the last `days` days: per day, by kind, by subject, by hour. */
  async usage(days = 14, now = new Date()) {
    const since = windowStart(now, days);

    const [perDay, perKind, perSubject, perHour, sessions] = await Promise.all([
      this.prisma.$queryRaw<
        { day: string; calls: number; cost: number; errors: number }[]
      >(Prisma.sql`
        SELECT to_char("createdAt" AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS day,
               count(*)::int AS calls, coalesce(sum("costUsd"), 0)::float AS cost,
               count(*) FILTER (WHERE NOT "ok")::int AS errors
        FROM "UsageLog" WHERE "createdAt" >= ${since} GROUP BY 1 ORDER BY 1`),
      this.prisma.$queryRaw<
        {
          kind: string;
          calls: number;
          cost: number;
          avgMs: number;
          errors: number;
        }[]
      >(Prisma.sql`
        SELECT "kind"::text AS kind, count(*)::int AS calls,
               coalesce(sum("costUsd"), 0)::float AS cost,
               coalesce(avg("durationMs"), 0)::int AS "avgMs",
               count(*) FILTER (WHERE NOT "ok")::int AS errors
        FROM "UsageLog" WHERE "createdAt" >= ${since} GROUP BY 1 ORDER BY 2 DESC`),
      this.prisma.$queryRaw<
        { subject: string; questions: number; learners: number }[]
      >(
        Prisma.sql`
        SELECT "subject", count(*)::int AS questions,
               count(DISTINCT "studentId")::int AS learners
        FROM "LearningEvent" WHERE "createdAt" >= ${since} GROUP BY 1 ORDER BY 2 DESC`,
      ),
      this.prisma.$queryRaw<{ hour: number; questions: number }[]>(Prisma.sql`
        SELECT extract(hour FROM "createdAt" AT TIME ZONE 'UTC')::int AS hour,
               count(*)::int AS questions
        FROM "LearningEvent" WHERE "createdAt" >= ${since} GROUP BY 1 ORDER BY 1`),
      this.prisma.$queryRaw<{ day: string; sessions: number }[]>(Prisma.sql`
        SELECT to_char("createdAt" AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS day,
               count(DISTINCT "studentId")::int AS sessions
        FROM "UsageLog" WHERE "createdAt" >= ${since} AND "studentId" IS NOT NULL
        GROUP BY 1`),
    ]);

    const sessionsByDay = new Map(sessions.map((s) => [s.day, s.sessions]));
    const daily = fillDays(
      now,
      days,
      perDay.map((d) => ({ ...d, sessions: sessionsByDay.get(d.day) ?? 0 })),
      (day) => ({ day, calls: 0, cost: 0, errors: 0, sessions: 0 }),
    );
    const totalCost = daily.reduce((n, d) => n + d.cost, 0);
    const totalSessions = daily.reduce((n, d) => n + d.sessions, 0);

    return {
      days,
      daily,
      totals: {
        calls: daily.reduce((n, d) => n + d.calls, 0),
        cost: totalCost,
        errors: daily.reduce((n, d) => n + d.errors, 0),
        sessions: totalSessions,
        costPerSession: totalSessions ? totalCost / totalSessions : 0,
      },
      byKind: perKind,
      bySubject: perSubject,
      byHour: Array.from({ length: 24 }, (_, hour) => ({
        hour,
        questions: perHour.find((h) => h.hour === hour)?.questions ?? 0,
      })),
    };
  }

  async students(query: { search?: string; take?: number; skip?: number }) {
    const where: Prisma.StudentWhereInput = query.search
      ? {
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            {
              user: {
                fullName: { contains: query.search, mode: 'insensitive' },
              },
            },
            {
              user: { email: { contains: query.search, mode: 'insensitive' } },
            },
          ],
        }
      : {};
    const [total, rows] = await Promise.all([
      this.prisma.student.count({ where }),
      this.prisma.student.findMany({
        where,
        orderBy: [
          { stats: { lastActiveAt: { sort: 'desc', nulls: 'last' } } },
          { createdAt: 'desc' },
        ],
        take: query.take ?? 50,
        skip: query.skip ?? 0,
        select: {
          id: true,
          name: true,
          grade: true,
          createdAt: true,
          user: { select: { fullName: true, email: true, role: true } },
          stats: true,
        },
      }),
    ]);

    const since = windowStart(new Date(), 30);
    const costs = await this.prisma.usageLog.groupBy({
      by: ['studentId'],
      where: {
        studentId: { in: rows.map((r) => r.id) },
        createdAt: { gte: since },
      },
      _sum: { costUsd: true },
      _count: { _all: true },
    });
    const costById = new Map(costs.map((c) => [c.studentId, c]));

    return {
      total,
      students: rows.map((s) => ({
        id: s.id,
        name: s.name,
        grade: s.grade,
        joinedAt: s.createdAt,
        account: s.user.fullName,
        email: s.user.email,
        selfSignedUp: s.user.role === 'STUDENT',
        xp: s.stats?.xp ?? 0,
        level: levelForXp(s.stats?.xp ?? 0),
        streak: s.stats?.streak ?? 0,
        questions: s.stats?.questions ?? 0,
        lastActiveAt: s.stats?.lastActiveAt ?? null,
        aiCalls30Days: costById.get(s.id)?._count._all ?? 0,
        cost30Days: costById.get(s.id)?._sum.costUsd ?? 0,
      })),
    };
  }

  limits() {
    return this.settings.limits();
  }

  setLimits(next: Partial<Limits>) {
    return this.settings.setLimits(next);
  }

  private async activeLearners(since: Date) {
    const rows = await this.prisma.learningEvent.findMany({
      where: { createdAt: { gte: since } },
      distinct: ['studentId'],
      select: { studentId: true },
    });
    return rows.length;
  }

  private async spend(since: Date) {
    const r = await this.prisma.usageLog.aggregate({
      where: { createdAt: { gte: since } },
      _sum: { costUsd: true },
      _count: { _all: true },
    });
    return { cost: r._sum.costUsd ?? 0, calls: r._count._all };
  }

  private async spendBetween(from: Date, to: Date) {
    const r = await this.prisma.usageLog.aggregate({
      where: { createdAt: { gte: from, lt: to } },
      _sum: { costUsd: true },
    });
    return r._sum.costUsd ?? 0;
  }

  /** One learner in depth: profile, progress, mastery by unit and recent practice. */
  async student(id: string) {
    const s = await this.prisma.student.findUnique({
      where: { id },
      include: {
        user: { select: { fullName: true, email: true, role: true } },
        stats: true,
        badges: { orderBy: { earnedAt: 'desc' } },
        enrollments: { include: { subject: { select: { name: true } } } },
      },
    });
    if (!s) throw new NotFoundException('Learner not found');
    const [mastery, attempts, submissions, conversations, usage] =
      await Promise.all([
        this.prisma.topicMastery.findMany({
          where: { studentId: id },
          include: {
            topic: { select: { name: true, subject: true, code: true } },
          },
          orderBy: { lastAttemptAt: 'desc' },
        }),
        this.prisma.quizAttempt.findMany({
          where: { studentId: id, finishedAt: { not: null } },
          orderBy: { finishedAt: 'desc' },
          take: 15,
          include: { topic: { select: { name: true, subject: true } } },
        }),
        this.prisma.assignmentSubmission.findMany({
          where: { studentId: id },
          orderBy: { createdAt: 'desc' },
          take: 10,
        }),
        // Only how many: what a child said to the tutor is theirs and their parent's.
        this.prisma.conversation.count({ where: { studentId: id } }),
        this.prisma.usageLog.aggregate({
          where: {
            studentId: id,
            createdAt: { gte: windowStart(new Date(), 30) },
          },
          _sum: { costUsd: true },
          _count: { _all: true },
        }),
      ]);
    const taskTopics = new Map(
      (
        await this.prisma.quizTopic.findMany({
          where: { id: { in: submissions.map((a) => a.topicId) } },
          select: { id: true, name: true, subject: true },
        })
      ).map((t) => [t.id, t]),
    );
    return {
      id: s.id,
      name: s.name,
      grade: s.grade,
      joinedAt: s.createdAt,
      account: s.user.fullName,
      email: s.user.email,
      selfSignedUp: s.user.role === 'STUDENT',
      subjects: s.enrollments.map((e) => e.subject.name),
      hiddenFromLeaderboard: s.hideFromLeaderboard,
      stats: {
        xp: s.stats?.xp ?? 0,
        level: levelForXp(s.stats?.xp ?? 0),
        streak: s.stats?.streak ?? 0,
        bestStreak: s.stats?.bestStreak ?? 0,
        questions: s.stats?.questions ?? 0,
        quizzes: s.stats?.quizzes ?? 0,
        assignments: s.stats?.assignments ?? 0,
        masteredTopics: s.stats?.masteredTopics ?? 0,
        lastActiveAt: s.stats?.lastActiveAt ?? null,
      },
      badges: s.badges.map((b) => ({ code: b.code, earnedAt: b.earnedAt })),
      conversations,
      aiCalls30Days: usage._count._all,
      cost30Days: usage._sum.costUsd ?? 0,
      mastery: mastery.map((m) => ({
        topic: m.topic.name,
        subject: m.topic.subject,
        code: m.topic.code,
        state: m.state,
        attempts: m.attempts,
        bestScore: m.bestScore,
        lastScore: m.lastScore,
        lastAttemptAt: m.lastAttemptAt,
      })),
      attempts: attempts.map((a) => ({
        id: a.id,
        topic: a.topic.name,
        subject: a.topic.subject,
        mode: a.mode,
        score: a.score,
        finishedAt: a.finishedAt,
      })),
      assignments: submissions.map((a) => ({
        topic: taskTopics.get(a.topicId)?.name ?? '',
        subject: taskTopics.get(a.topicId)?.subject ?? '',
        verdict: a.verdict,
        at: a.createdAt,
      })),
    };
  }

  private async costPerSession(since: Date) {
    const [row] = await this.prisma.$queryRaw<
      { cost: number; sessions: number }[]
    >(
      Prisma.sql`
      SELECT coalesce(sum("costUsd"), 0)::float AS cost,
             (SELECT count(*) FROM (
                SELECT DISTINCT "studentId", date_trunc('day', "createdAt" AT TIME ZONE 'UTC')
                FROM "UsageLog" WHERE "createdAt" >= ${since} AND "studentId" IS NOT NULL
              ) s)::int AS sessions
      FROM "UsageLog" WHERE "createdAt" >= ${since}`,
    );
    return row && row.sessions ? row.cost / row.sessions : 0;
  }
}
