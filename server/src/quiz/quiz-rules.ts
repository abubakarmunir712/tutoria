import { MasteryState, QuizMode, Verdict } from '@prisma/client';

// The quiz rules as plain functions, so they can be tested without a database and changed in one
// place (see docs/QUIZ_PLAN.md).

export const QUIZ_QUESTIONS = 5;
export const CHECK_QUESTIONS = 3;
/** Each question gets this many tries; the first wrong try earns a nudge, not the answer. */
export const MAX_TRIES = 2;
export const STRONG_SCORE = 0.8;
export const PASS_SCORE = 0.5;
/** Shortest assignment response worth marking (characters, after trimming). */
export const MIN_ASSIGNMENT_CHARS = 40;

// ---- Matching ---------------------------------------------------------------------------

/** Lower case, no punctuation or extra spaces, thousands commas and currency signs removed. */
export function normalizeAnswer(text: string): string {
  return text
    .toLowerCase()
    .replace(/(\d),(?=\d{3}\b)/g, '$1')
    .replace(/gh[¢₵]|₵|¢|ghs|\$/g, '')
    .replace(/[^\p{L}\p{N}.\s%-]/gu, ' ')
    .replace(/(?<!\d)\.|\.(?!\d)/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const NUMBER = /-?\d+(?:\.\d+)?/g;

function numbersIn(text: string): number[] {
  return (normalizeAnswer(text).match(NUMBER) ?? []).map(Number);
}

function closeEnough(a: number, b: number): boolean {
  return Math.abs(a - b) <= Math.max(0.005, Math.abs(b) * 0.0005);
}

/**
 * True only when the answer plainly equals the expected one, so no AI call is needed. Anything
 * short of that is left to the marker; this never decides that an answer is wrong.
 */
export function isExactMatch(answer: string, expected: string): boolean {
  const a = normalizeAnswer(answer);
  const e = normalizeAnswer(expected);
  if (!a || !e) return false;
  if (a === e) return true;

  const expectedNumbers = numbersIn(expected);
  const wordsInExpected = e.split(' ').length;
  if (expectedNumbers.length === 1 && wordsInExpected === 1) {
    // "72" and "The answer is 72" both match "72"; "7 or 72" and "70" do not.
    const given = numbersIn(answer);
    return given.length === 1 && closeEnough(given[0], expectedNumbers[0]);
  }
  if (expectedNumbers.length === 0 && wordsInExpected <= 3) {
    // A short word answer ("Multiplication") inside a short sentence.
    const padded = ` ${a} `;
    return a.split(' ').length <= 8 && padded.includes(` ${e} `);
  }
  return false;
}

const STOP_WORDS = new Set(
  'the and for are that this with from have has was were not you your can will its into than then them they their what when which who how why use used using each any all one two out but also very more most some such only over under after before about between through during because'.split(
    ' ',
  ),
);

/** When the marker is unreachable: how much of the expected answer's key words appear. */
export function keywordVerdict(answer: string, expected: string): Verdict {
  const given = new Set(normalizeAnswer(answer).split(' '));
  const keys = [
    ...new Set(
      normalizeAnswer(expected)
        .split(' ')
        .filter((w) => w.length > 3 && !STOP_WORDS.has(w)),
    ),
  ];
  if (keys.length === 0) {
    // The reference is only guidance, so all we can say is whether a real attempt was made.
    return normalizeAnswer(answer).split(' ').filter(Boolean).length >= 2
      ? 'PARTIAL'
      : 'INCORRECT';
  }
  const hit = keys.filter((k) => given.has(k)).length / keys.length;
  if (hit >= 0.6) return 'CORRECT';
  if (hit >= 0.35) return 'PARTIAL';
  return 'INCORRECT';
}

// ---- Scoring ----------------------------------------------------------------------------

/** Points for one question: right first time 1, right on the retry 0.6, partly right 0.5. */
export function pointsFor(verdict: Verdict, tries: number): number {
  if (verdict === 'CORRECT') return tries <= 1 ? 1 : 0.6;
  if (verdict === 'PARTIAL') return 0.5;
  return 0;
}

export function scoreOf(points: number[]): number {
  if (points.length === 0) return 0;
  const sum = points.reduce((n, p) => n + p, 0);
  return Math.round((sum / points.length) * 1000) / 1000;
}

// ---- Mastery ----------------------------------------------------------------------------

export interface MasteryFacts {
  state: MasteryState;
  strongAttempts: number;
}

const RANK: Record<MasteryState, number> = {
  NEEDS_REVISION: 0,
  EMERGING: 1,
  DEVELOPING: 2,
  SECURE: 3,
  MASTERED: 4,
};

function stateForScore(score: number): MasteryState {
  if (score >= STRONG_SCORE) return 'SECURE';
  if (score >= PASS_SCORE) return 'DEVELOPING';
  return 'EMERGING';
}

/**
 * Where a learner stands on a unit after finishing a quiz or quick check.
 *
 * - A quick check can lift a unit to Developing at most, and never lowers it.
 * - A quiz at 80%+ is Secure; Mastered also needs a second 80%+ quiz *and* the unfamiliar-transfer
 *   question right this time ("more than one example and successful unfamiliar transfer").
 * - Someone who was Secure or Mastered keeps that through a so-so quiz, and goes to Needs Revision
 *   only on a poor one (under 50%).
 */
export function nextMastery(
  prev: MasteryFacts | null,
  result: { mode: QuizMode; score: number; transferCorrect: boolean },
): MasteryFacts {
  const strongBefore = prev?.strongAttempts ?? 0;

  if (result.mode === 'CHECK') {
    const base: MasteryState =
      result.score >= PASS_SCORE ? 'DEVELOPING' : 'EMERGING';
    const state = prev && RANK[prev.state] >= RANK[base] ? prev.state : base;
    return { state, strongAttempts: strongBefore };
  }

  const strong = strongBefore + (result.score >= STRONG_SCORE ? 1 : 0);
  let state = stateForScore(result.score);

  if (result.score >= STRONG_SCORE && strong >= 2 && result.transferCorrect) {
    state = 'MASTERED';
  } else if (prev && RANK[prev.state] >= RANK.SECURE) {
    state =
      result.score < PASS_SCORE
        ? 'NEEDS_REVISION'
        : RANK[prev.state] > RANK[state]
          ? prev.state
          : state;
  }
  return { state, strongAttempts: strong };
}

export const MASTERY_LABEL: Record<MasteryState | 'NOT_STARTED', string> = {
  NOT_STARTED: 'Not started',
  EMERGING: 'Emerging',
  DEVELOPING: 'Developing',
  SECURE: 'Secure',
  MASTERED: 'Mastered',
  NEEDS_REVISION: 'Needs revision',
};

// ---- XP ---------------------------------------------------------------------------------

/** A quick check pays half a quiz. */
const CHECK_FACTOR = 0.5;

/**
 * XP for finishing a quiz or quick check. The first finish of a unit pays 10 + up to 30 for the
 * score; replaying pays only for beating your best score before, so repeating a quiz can't be used
 * to farm XP.
 */
export function quizXp(
  mode: QuizMode,
  score: number,
  previousBest: number | null,
): number {
  const raw =
    previousBest === null
      ? 10 + 30 * score
      : 30 * Math.max(0, score - previousBest);
  return Math.round(mode === 'CHECK' ? raw * CHECK_FACTOR : raw);
}

export const ASSIGNMENT_XP: Record<Verdict, number> = {
  CORRECT: 20,
  PARTIAL: 10,
  INCORRECT: 0,
};

/** An assignment pays once per unit; a better resubmission pays the difference. */
export function assignmentXp(verdict: Verdict, bestPreviousXp: number): number {
  return Math.max(0, ASSIGNMENT_XP[verdict] - bestPreviousXp);
}

// ---- Unit lists -------------------------------------------------------------------------

/** Counts by state, for the headline numbers. */
export function summarise(states: (MasteryState | 'NOT_STARTED')[]) {
  const n = (s: MasteryState) => states.filter((x) => x === s).length;
  return {
    total: states.length,
    started: states.filter((s) => s !== 'NOT_STARTED').length,
    mastered: n('MASTERED'),
    secure: n('SECURE'),
    developing: n('DEVELOPING') + n('EMERGING'),
    needsRevision: n('NEEDS_REVISION'),
  };
}

/**
 * The unit to suggest next: one that slipped back first, otherwise the first one in teaching
 * order that is not yet Secure. `except` skips the unit just finished.
 */
export function recommended(
  units: { id: string; state?: MasteryState }[],
  except?: string,
): string | null {
  const pool = units.filter((u) => u.id !== except);
  return (
    (
      pool.find((u) => u.state === 'NEEDS_REVISION') ??
      pool.find((u) => u.state !== 'SECURE' && u.state !== 'MASTERED') ??
      null
    )?.id ?? null
  );
}
