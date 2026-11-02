import { Injectable, NotFoundException } from '@nestjs/common';
import { EventKind, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { publicName, rankBoard, weekStart } from './leaderboard';
import {
  ASK_KINDS,
  BADGES,
  BadgeFacts,
  XpAward,
  currentStreak,
  levelForXp,
  levelProgress,
  newBadges,
  nextStreak,
  utcDayKey,
  xpFor,
} from './gamification';

export interface RecordedProgress {
  xpGained: number;
  award: XpAward;
  xp: number;
  level: number;
  leveledUp: boolean;
  streak: number;
  newBadges: { code: string; name: string; description: string }[];
}

const WEEK_DAYS = 7;
const ACTIVE_DAYS_WINDOW = 120;

@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  /** The learner's id, if (and only if) it belongs to this user. */
  async requireOwned(userId: string, studentId: string): Promise<string> {
    const student = await this.prisma.student.findFirst({
      where: { id: studentId, userId },
      select: { id: true },
    });
    if (!student) throw new NotFoundException('Student not found');
    return student.id;
  }

  /** Add up one learning action: XP, streak, level and any badges it unlocks. */
  async record(
    studentId: string,
    action: {
      kind: EventKind;
      subject: string;
      topic?: string;
      /** What a quiz or assignment earned; tutor questions use the fixed amounts. */
      baseXp?: number;
      /** A quiz with every question right. */
      perfect?: boolean;
    },
    now = new Date(),
  ): Promise<RecordedProgress> {
    const today = utcDayKey(now);
    const dayStart = new Date(`${today}T00:00:00.000Z`);

    return this.prisma.$transaction(async (tx) => {
      const stats = await tx.studentStats.upsert({
        where: { studentId },
        create: { studentId },
        update: {},
      });
      const eventsToday = await tx.learningEvent.count({
        where: { studentId, createdAt: { gte: dayStart } },
      });

      const firstOfDay = stats.lastActiveDay !== today;
      const streak = firstOfDay
        ? nextStreak(stats.streak, stats.lastActiveDay, today)
        : Math.max(stats.streak, 1);
      const award = xpFor(action.kind, {
        firstOfDay,
        streakAfter: streak,
        eventsToday,
        baseXp: action.baseXp,
      });

      await tx.learningEvent.create({
        data: {
          studentId,
          kind: action.kind,
          subject: action.subject,
          topic: action.topic?.slice(0, 120),
          xp: award.total,
          createdAt: now,
        },
      });

      const xp = stats.xp + award.total;
      const asked = ASK_KINDS.includes(action.kind);
      const questions = stats.questions + (asked ? 1 : 0);
      const photos = stats.photos + (action.kind === 'PHOTO' ? 1 : 0);
      const voices = stats.voices + (action.kind === 'VOICE' ? 1 : 0);
      const quizzes = stats.quizzes + (action.kind === 'QUIZ' ? 1 : 0);
      const perfectQuizzes = stats.perfectQuizzes + (action.perfect ? 1 : 0);
      const assignments =
        stats.assignments + (action.kind === 'ASSIGNMENT' ? 1 : 0);
      const masteredTopics = await tx.topicMastery.count({
        where: { studentId, state: 'MASTERED' },
      });
      const bestStreak = Math.max(stats.bestStreak, streak);

      const subjects = await tx.learningEvent.findMany({
        where: { studentId },
        distinct: ['subject'],
        select: { subject: true },
      });
      const have = await tx.studentBadge.findMany({
        where: { studentId },
        select: { code: true },
      });
      const facts: BadgeFacts = {
        questions,
        photos,
        voices,
        streak,
        bestStreak,
        subjects: subjects.length,
        level: levelForXp(xp),
        quizzes,
        perfectQuizzes,
        assignments,
        masteredTopics,
      };
      const earned = newBadges(
        facts,
        have.map((b) => b.code),
      );
      if (earned.length) {
        await tx.studentBadge.createMany({
          data: earned.map((b) => ({ studentId, code: b.code, earnedAt: now })),
          skipDuplicates: true,
        });
      }

      await tx.studentStats.update({
        where: { studentId },
        data: {
          xp,
          questions,
          photos,
          voices,
          quizzes,
          perfectQuizzes,
          assignments,
          masteredTopics,
          streak,
          bestStreak,
          lastActiveDay: today,
          lastActiveAt: now,
          // "Continue learning" reopens the tutor, so only tutor questions set where to resume.
          ...(asked
            ? {
                lastSubject: action.subject,
                lastTopic: action.topic?.slice(0, 120) ?? null,
              }
            : {}),
        },
      });

      return {
        xpGained: award.total,
        award,
        xp,
        level: levelForXp(xp),
        leveledUp: levelForXp(xp) > levelForXp(stats.xp),
        streak,
        newBadges: earned.map(({ code, name, description }) => ({
          code,
          name,
          description,
        })),
      };
    });
  }

  /** Everything a screen needs to show how one learner is doing. */
  async summary(studentId: string, now = new Date()) {
    const today = utcDayKey(now);
    const windowStart = new Date(`${today}T00:00:00.000Z`);
    windowStart.setUTCDate(windowStart.getUTCDate() - (ACTIVE_DAYS_WINDOW - 1));

    const [stats, bySubjectRows, perDay, topicRows, badgeRows] =
      await Promise.all([
        this.prisma.studentStats.findUnique({ where: { studentId } }),
        this.prisma.learningEvent.groupBy({
          by: ['subject'],
          where: { studentId },
          _count: { _all: true },
        }),
        this.prisma.$queryRaw<{ day: string; count: number; xp: number }[]>(
          Prisma.sql`SELECT to_char("createdAt" AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS day,
                            count(*)::int AS count, coalesce(sum("xp"), 0)::int AS xp
                     FROM "LearningEvent"
                     WHERE "studentId" = ${studentId} AND "createdAt" >= ${windowStart}
                     GROUP BY 1 ORDER BY 1`,
        ),
        this.prisma.learningEvent.findMany({
          where: {
            studentId,
            topic: { not: null },
            kind: { in: ASK_KINDS },
          },
          orderBy: { createdAt: 'desc' },
          take: 40,
          select: { subject: true, topic: true, createdAt: true },
        }),
        this.prisma.studentBadge.findMany({ where: { studentId } }),
      ]);

    const xp = stats?.xp ?? 0;
    const dayMap = new Map(perDay.map((d) => [d.day, d]));
    const week = Array.from({ length: WEEK_DAYS }, (_, i) => {
      const d = new Date(`${today}T00:00:00.000Z`);
      d.setUTCDate(d.getUTCDate() - (WEEK_DAYS - 1 - i));
      const day = utcDayKey(d);
      return {
        day,
        count: dayMap.get(day)?.count ?? 0,
        xp: dayMap.get(day)?.xp ?? 0,
      };
    });

    const seen = new Set<string>();
    const recentTopics: { subject: string; topic: string; at: Date }[] = [];
    for (const r of topicRows) {
      const key = `${r.subject}|${r.topic}`;
      if (seen.has(key) || !r.topic) continue;
      seen.add(key);
      recentTopics.push({
        subject: r.subject,
        topic: r.topic,
        at: r.createdAt,
      });
      if (recentTopics.length === 5) break;
    }

    const earnedAt = new Map(badgeRows.map((b) => [b.code, b.earnedAt]));

    return {
      studentId,
      xp,
      ...levelProgress(xp),
      streak: currentStreak(
        stats?.streak ?? 0,
        stats?.lastActiveDay ?? null,
        today,
      ),
      bestStreak: stats?.bestStreak ?? 0,
      questions: stats?.questions ?? 0,
      photos: stats?.photos ?? 0,
      voices: stats?.voices ?? 0,
      quizzes: stats?.quizzes ?? 0,
      assignments: stats?.assignments ?? 0,
      masteredTopics: stats?.masteredTopics ?? 0,
      lastSubject: stats?.lastSubject ?? null,
      lastTopic: stats?.lastTopic ?? null,
      lastActiveAt: stats?.lastActiveAt ?? null,
      bySubject: Object.fromEntries(
        bySubjectRows.map((r) => [r.subject, r._count._all]),
      ),
      days: perDay.map((d) => d.day),
      week,
      questionsThisWeek: week.reduce((n, d) => n + d.count, 0),
      xpThisWeek: week.reduce((n, d) => n + d.xp, 0),
      recentTopics,
      badges: BADGES.map((b) => ({
        code: b.code,
        name: b.name,
        description: b.description,
        earned: earnedAt.has(b.code),
        earnedAt: earnedAt.get(b.code) ?? null,
      })),
    };
  }

  /**
   * This week's XP board for the learner's class (everyone in the same grade). Learners who
   * opted out are left off, and only a first name and initial are shown.
   */
  async leaderboard(userId: string, studentId: string, now = new Date()) {
    await this.requireOwned(userId, studentId);
    const me = await this.prisma.student.findUniqueOrThrow({
      where: { id: studentId },
      select: { grade: true, hideFromLeaderboard: true },
    });
    const since = weekStart(now);
    if (!me.grade) {
      return {
        week: since,
        hidden: me.hideFromLeaderboard,
        top: [],
        you: null,
      };
    }
    const sums = await this.prisma.learningEvent.groupBy({
      by: ['studentId'],
      where: {
        createdAt: { gte: since },
        student: { grade: me.grade, hideFromLeaderboard: false },
      },
      _sum: { xp: true },
    });
    const names = await this.prisma.student.findMany({
      where: { id: { in: sums.map((s) => s.studentId) } },
      select: { id: true, name: true },
    });
    const nameOf = new Map(names.map((n) => [n.id, n.name]));
    const entries = sums
      .filter((s) => (s._sum.xp ?? 0) > 0)
      .map((s) => ({
        studentId: s.studentId,
        name: publicName(nameOf.get(s.studentId) ?? ''),
        xp: s._sum.xp ?? 0,
      }));
    const { top, you } = rankBoard(entries, studentId);
    // Never send other children's ids to the app: only rank, name and XP.
    const shape = (r: (typeof top)[number]) => ({
      rank: r.rank,
      name: r.name,
      xp: r.xp,
      isYou: r.isYou,
    });
    return {
      week: since,
      hidden: me.hideFromLeaderboard,
      top: top.map(shape),
      you: you ? shape(you) : null,
    };
  }

  async setLeaderboardVisible(
    userId: string,
    studentId: string,
    visible: boolean,
  ) {
    await this.requireOwned(userId, studentId);
    await this.prisma.student.update({
      where: { id: studentId },
      data: { hideFromLeaderboard: !visible },
    });
    return { hidden: !visible };
  }

  async summaryFor(userId: string, studentId: string) {
    await this.requireOwned(userId, studentId);
    return this.summary(studentId);
  }

  /** Every learner this user looks after (a parent's children, or a student themselves). */
  async summariesFor(userId: string) {
    const students = await this.prisma.student.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      select: { id: true, name: true, grade: true },
    });
    return Promise.all(
      students.map(async (s) => ({
        name: s.name,
        grade: s.grade,
        ...(await this.summary(s.id)),
      })),
    );
  }
}
