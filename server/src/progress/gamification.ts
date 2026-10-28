import { EventKind } from '@prisma/client';

// All of the game rules live here as plain functions, so they can be tested without a database
// and changed in one place.

/** XP for one action. Quizzes and assignments will add their own entries. */
export const XP_PER_EVENT: Record<EventKind, number> = {
  QUESTION: 10,
  PHOTO: 15,
  VOICE: 10,
};

/** Extra XP for the first thing a learner does each day. */
export const FIRST_OF_DAY_BONUS = 10;

/** Extra XP the day a streak reaches one of these lengths. */
export const STREAK_BONUS: Record<number, number> = {
  3: 20,
  7: 50,
  14: 100,
  30: 250,
};

/** After this many XP-earning actions in a day, more questions are still answered but earn
 *  nothing, so asking the same thing over and over can't farm XP. */
export const DAILY_XP_EVENT_CAP = 30;

/** yyyy-MM-dd in UTC (Ghana is on UTC, so this is the learner's calendar day). */
export function utcDayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function previousDayKey(day: string): string {
  const d = new Date(`${day}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return utcDayKey(d);
}

/** The streak after activity on `today`, given the streak and last active day so far. */
export function nextStreak(
  streak: number,
  lastActiveDay: string | null,
  today: string,
): number {
  if (lastActiveDay === today) return Math.max(streak, 1);
  if (lastActiveDay === previousDayKey(today)) return streak + 1;
  return 1;
}

/** The streak a learner still has right now: it survives until the end of the day after their
 *  last activity, then is gone. (Stored streaks only update on activity.) */
export function currentStreak(
  streak: number,
  lastActiveDay: string | null,
  today: string,
): number {
  if (!lastActiveDay) return 0;
  return lastActiveDay === today || lastActiveDay === previousDayKey(today)
    ? streak
    : 0;
}

// Level n starts at 50 * (n - 1)^2 XP: 0, 50, 200, 450, 800 ... quick early wins, then slower.
export function levelForXp(xp: number): number {
  return Math.floor(Math.sqrt(Math.max(xp, 0) / 50)) + 1;
}

export function levelProgress(xp: number) {
  const level = levelForXp(xp);
  const from = 50 * (level - 1) ** 2;
  const to = 50 * level ** 2;
  return {
    level,
    levelStartXp: from,
    nextLevelXp: to,
    xpIntoLevel: xp - from,
    xpForLevel: to - from,
  };
}

export interface BadgeFacts {
  questions: number;
  photos: number;
  voices: number;
  streak: number;
  bestStreak: number;
  subjects: number;
  level: number;
}

export interface BadgeDef {
  code: string;
  name: string;
  description: string;
  earned: (f: BadgeFacts) => boolean;
}

export const BADGES: BadgeDef[] = [
  {
    code: 'first_question',
    name: 'First Steps',
    description: 'Ask your very first question',
    earned: (f) => f.questions >= 1,
  },
  {
    code: 'questions_10',
    name: 'Curious Mind',
    description: 'Ask 10 questions',
    earned: (f) => f.questions >= 10,
  },
  {
    code: 'questions_50',
    name: 'Question Machine',
    description: 'Ask 50 questions',
    earned: (f) => f.questions >= 50,
  },
  {
    code: 'questions_100',
    name: 'Knowledge Seeker',
    description: 'Ask 100 questions',
    earned: (f) => f.questions >= 100,
  },
  {
    code: 'streak_3',
    name: 'On a Roll',
    description: 'Learn 3 days in a row',
    earned: (f) => f.bestStreak >= 3,
  },
  {
    code: 'streak_7',
    name: 'Week Warrior',
    description: 'Learn 7 days in a row',
    earned: (f) => f.bestStreak >= 7,
  },
  {
    code: 'streak_30',
    name: 'Unstoppable',
    description: 'Learn 30 days in a row',
    earned: (f) => f.bestStreak >= 30,
  },
  {
    code: 'photo_homework',
    name: 'Snap and Solve',
    description: 'Get help with a homework photo',
    earned: (f) => f.photos >= 1,
  },
  {
    code: 'voice_question',
    name: 'Speak Up',
    description: 'Ask a question out loud',
    earned: (f) => f.voices >= 1,
  },
  {
    code: 'explorer',
    name: 'Explorer',
    description: 'Learn in 3 different subjects',
    earned: (f) => f.subjects >= 3,
  },
  {
    code: 'level_5',
    name: 'Rising Star',
    description: 'Reach level 5',
    earned: (f) => f.level >= 5,
  },
];

/** Badges the learner now qualifies for and doesn't already have. */
export function newBadges(
  facts: BadgeFacts,
  have: Iterable<string>,
): BadgeDef[] {
  const owned = new Set(have);
  return BADGES.filter((b) => !owned.has(b.code) && b.earned(facts));
}

export interface XpAward {
  base: number;
  firstOfDay: number;
  streak: number;
  total: number;
}

/** What one action earns. `eventsToday` counts XP-earning actions already made today. */
export function xpFor(
  kind: EventKind,
  opts: { firstOfDay: boolean; streakAfter: number; eventsToday: number },
): XpAward {
  if (opts.eventsToday >= DAILY_XP_EVENT_CAP) {
    return { base: 0, firstOfDay: 0, streak: 0, total: 0 };
  }
  const base = XP_PER_EVENT[kind];
  const firstOfDay = opts.firstOfDay ? FIRST_OF_DAY_BONUS : 0;
  // Only on the day the streak first reaches the milestone.
  const streak = opts.firstOfDay ? (STREAK_BONUS[opts.streakAfter] ?? 0) : 0;
  return { base, firstOfDay, streak, total: base + firstOfDay + streak };
}
