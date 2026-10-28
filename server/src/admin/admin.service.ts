import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { levelForXp, utcDayKey } from '../progress/gamification';
import { PrismaService } from '../prisma/prisma.service';
import { Limits, SettingsService } from '../usage/settings.service';
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
    ]);

    return {
      generatedAt: now,
      people: { parents, learners },
      active: {
        today: activeToday,
        last7Days: active7d,
        last30Days: active30d,
      },
      questions: { today: questionsToday, last7Days: questions7d },
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
