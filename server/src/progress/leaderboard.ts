/** The class leaderboard's rules: who is shown, under what name, and who ranks where. */

/** Learners shown at the top of the board. */
export const TOP_N = 10;

/** "Ama Mensah" -> "Ama M." Other families' children see a first name and an initial only. */
export function publicName(full: string): string {
  const parts = full.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'Learner';
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[parts.length - 1][0].toUpperCase()}.`;
}

/** Monday 00:00 UTC of the week containing [now]. Ghana is on UTC, so this is the learners' week. */
export function weekStart(now: Date): Date {
  const day = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  const sinceMonday = (day.getUTCDay() + 6) % 7;
  return new Date(day.getTime() - sinceMonday * 24 * 60 * 60 * 1000);
}

export interface Entry {
  studentId: string;
  name: string;
  xp: number;
}

export interface Ranked extends Entry {
  rank: number;
  isYou: boolean;
}

/**
 * Rank by XP, highest first; ties share a rank (1, 2, 2, 4). Returns the top [TOP_N] and, when
 * the learner is further down, their own row too so they can see where they stand.
 */
export function rankBoard(
  entries: Entry[],
  meId: string,
): { top: Ranked[]; you: Ranked | null } {
  const sorted = [...entries].sort(
    (a, b) => b.xp - a.xp || a.name.localeCompare(b.name),
  );
  const ranked: Ranked[] = [];
  sorted.forEach((e, i) => {
    const tied = i > 0 && sorted[i - 1].xp === e.xp;
    ranked.push({
      ...e,
      rank: tied ? ranked[i - 1].rank : i + 1,
      isYou: e.studentId === meId,
    });
  });
  const top = ranked.slice(0, TOP_N);
  const you = ranked.find((r) => r.isYou) ?? null;
  return { top, you: you && !top.includes(you) ? you : null };
}
