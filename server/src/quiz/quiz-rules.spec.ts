import {
  assignmentXp,
  isExactMatch,
  keywordVerdict,
  nextMastery,
  normalizeAnswer,
  pointsFor,
  quizXp,
  recommended,
  scoreOf,
  summarise,
} from './quiz-rules';

describe('answer matching', () => {
  it('ignores case, punctuation, commas and currency signs', () => {
    expect(normalizeAnswer('  GH₵ 1,250.50! ')).toBe('1250.50');
    expect(isExactMatch('10,000', '10000')).toBe(true);
    expect(isExactMatch('Multiplication.', 'multiplication')).toBe(true);
  });

  it('accepts a number inside a short sentence, but not a different or extra number', () => {
    expect(isExactMatch('The answer is 72', '72')).toBe(true);
    expect(isExactMatch('70', '72')).toBe(false);
    expect(isExactMatch('7 or 72', '72')).toBe(false);
    expect(isExactMatch('15', '5')).toBe(false);
  });

  it('allows a small rounding difference on decimals', () => {
    expect(isExactMatch('42.17', '42.1667')).toBe(true);
    expect(isExactMatch('42.5', '42.1667')).toBe(false);
  });

  it('finds a short word answer inside a short sentence, as a whole word', () => {
    expect(isExactMatch('I would use multiplication', 'Multiplication')).toBe(
      true,
    );
    expect(isExactMatch('multiplications', 'Multiplication')).toBe(false);
  });

  it('never calls a long reference answer an exact match unless it is identical', () => {
    const expected = 'An expression that can be evaluated as true or false.';
    expect(isExactMatch('something else', expected)).toBe(false);
    expect(isExactMatch(expected.toUpperCase(), expected)).toBe(true);
  });

  it('does not match an empty answer', () => {
    expect(isExactMatch('   ', '5')).toBe(false);
  });
});

describe('keyword fallback', () => {
  const expected = 'A feature or behaviour that helps an organism survive.';
  it('marks by how many key words appear', () => {
    expect(
      keywordVerdict('a feature that helps an organism survive', expected),
    ).toBe('CORRECT');
    expect(keywordVerdict('it helps', expected)).not.toBe('CORRECT');
    expect(keywordVerdict('the sky is blue', expected)).toBe('INCORRECT');
  });
  it('only checks effort when the reference is guidance', () => {
    expect(keywordVerdict('one thousand', 'Use the')).toBe('PARTIAL');
    expect(keywordVerdict('x', 'Use the')).toBe('INCORRECT');
  });
});

describe('scoring', () => {
  it('pays less for a retry and half for a partial', () => {
    expect(pointsFor('CORRECT', 1)).toBe(1);
    expect(pointsFor('CORRECT', 2)).toBe(0.6);
    expect(pointsFor('PARTIAL', 2)).toBe(0.5);
    expect(pointsFor('INCORRECT', 1)).toBe(0);
  });
  it('averages points', () => {
    expect(scoreOf([1, 1, 0.6, 0.5, 0])).toBe(0.62);
    expect(scoreOf([])).toBe(0);
  });
});

describe('mastery', () => {
  const quiz = (score: number, transferCorrect = false) =>
    ({ mode: 'QUIZ', score, transferCorrect }) as const;

  it('starts from the first score', () => {
    expect(nextMastery(null, quiz(0.2)).state).toBe('EMERGING');
    expect(nextMastery(null, quiz(0.6)).state).toBe('DEVELOPING');
    expect(nextMastery(null, quiz(1, true)).state).toBe('SECURE');
  });

  it('needs two strong quizzes and the transfer question for Mastered', () => {
    const first = nextMastery(null, quiz(1, true));
    expect(first).toEqual({ state: 'SECURE', strongAttempts: 1 });
    expect(nextMastery(first, quiz(0.9, false)).state).toBe('SECURE');
    expect(nextMastery(first, quiz(0.9, true)).state).toBe('MASTERED');
  });

  it('keeps Secure/Mastered through a so-so quiz, drops on a poor one', () => {
    const secure = { state: 'SECURE', strongAttempts: 1 } as const;
    expect(nextMastery(secure, quiz(0.6)).state).toBe('SECURE');
    expect(nextMastery(secure, quiz(0.3)).state).toBe('NEEDS_REVISION');
    const mastered = { state: 'MASTERED', strongAttempts: 2 } as const;
    expect(nextMastery(mastered, quiz(0.7)).state).toBe('MASTERED');
  });

  it('lets a learner recover from Needs Revision', () => {
    const slipped = { state: 'NEEDS_REVISION', strongAttempts: 1 } as const;
    expect(nextMastery(slipped, quiz(0.6)).state).toBe('DEVELOPING');
    expect(nextMastery(slipped, quiz(0.85)).state).toBe('SECURE');
  });

  it('lifts a unit to Developing at most from a quick check, and never lowers it', () => {
    const check = (score: number) =>
      ({ mode: 'CHECK', score, transferCorrect: false }) as const;
    expect(nextMastery(null, check(1)).state).toBe('DEVELOPING');
    expect(nextMastery(null, check(0.2)).state).toBe('EMERGING');
    const secure = { state: 'SECURE', strongAttempts: 1 } as const;
    expect(nextMastery(secure, check(0)).state).toBe('SECURE');
    expect(nextMastery(secure, check(1)).strongAttempts).toBe(1);
  });
});

describe('xp', () => {
  it('pays 10 plus up to 30 for the first finish', () => {
    expect(quizXp('QUIZ', 1, null)).toBe(40);
    expect(quizXp('QUIZ', 0, null)).toBe(10);
    expect(quizXp('QUIZ', 0.6, null)).toBe(28);
  });
  it('pays only the improvement on a replay', () => {
    expect(quizXp('QUIZ', 0.6, 0.6)).toBe(0);
    expect(quizXp('QUIZ', 0.4, 0.6)).toBe(0);
    expect(quizXp('QUIZ', 1, 0.6)).toBe(12);
  });
  it('pays half for a quick check', () => {
    expect(quizXp('CHECK', 1, null)).toBe(20);
  });
  it('pays an assignment once, then only a better result', () => {
    expect(assignmentXp('CORRECT', 0)).toBe(20);
    expect(assignmentXp('PARTIAL', 0)).toBe(10);
    expect(assignmentXp('CORRECT', 10)).toBe(10);
    expect(assignmentXp('PARTIAL', 20)).toBe(0);
    expect(assignmentXp('INCORRECT', 0)).toBe(0);
  });
});

describe('summarise', () => {
  it('counts units by where the learner is', () => {
    expect(
      summarise([
        'MASTERED',
        'SECURE',
        'DEVELOPING',
        'EMERGING',
        'NEEDS_REVISION',
        'NOT_STARTED',
      ]),
    ).toEqual({
      total: 6,
      started: 5,
      mastered: 1,
      secure: 1,
      developing: 2,
      needsRevision: 1,
    });
  });
});

describe('recommended', () => {
  const units = (...states: (string | undefined)[]) =>
    states.map((state, i) => ({ id: `u${i}`, state: state as never }));

  it('suggests the first unit that is not yet Secure', () => {
    expect(
      recommended(units('MASTERED', 'SECURE', 'DEVELOPING', undefined)),
    ).toBe('u2');
  });
  it('suggests a unit that slipped back before anything new', () => {
    expect(recommended(units('SECURE', undefined, 'NEEDS_REVISION'))).toBe(
      'u2',
    );
  });
  it('skips the unit just finished, and is null when everything is Secure', () => {
    expect(recommended(units(undefined, undefined), 'u0')).toBe('u1');
    expect(recommended(units('SECURE', 'MASTERED'))).toBeNull();
  });
});
