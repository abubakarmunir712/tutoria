import {
  BADGES,
  DAILY_XP_EVENT_CAP,
  currentStreak,
  levelForXp,
  levelProgress,
  newBadges,
  nextStreak,
  previousDayKey,
  xpFor,
} from './gamification';

describe('streaks', () => {
  it('starts at 1, grows on consecutive days, resets after a gap', () => {
    expect(nextStreak(0, null, '2026-10-24')).toBe(1);
    expect(nextStreak(4, '2026-10-23', '2026-10-24')).toBe(5);
    expect(nextStreak(4, '2026-10-24', '2026-10-24')).toBe(4);
    expect(nextStreak(4, '2026-10-22', '2026-10-24')).toBe(1);
  });

  it('counts across month and year boundaries', () => {
    expect(previousDayKey('2026-11-01')).toBe('2026-10-31');
    expect(previousDayKey('2027-01-01')).toBe('2026-12-31');
    expect(nextStreak(2, '2026-12-31', '2027-01-01')).toBe(3);
  });

  it('keeps the streak until the end of the day after the last activity', () => {
    expect(currentStreak(6, '2026-10-24', '2026-10-24')).toBe(6);
    expect(currentStreak(6, '2026-10-23', '2026-10-24')).toBe(6);
    expect(currentStreak(6, '2026-10-22', '2026-10-24')).toBe(0);
    expect(currentStreak(0, null, '2026-10-24')).toBe(0);
  });
});

describe('levels', () => {
  it('moves up at 50, 200, 450 XP', () => {
    expect(levelForXp(0)).toBe(1);
    expect(levelForXp(49)).toBe(1);
    expect(levelForXp(50)).toBe(2);
    expect(levelForXp(199)).toBe(2);
    expect(levelForXp(200)).toBe(3);
    expect(levelForXp(450)).toBe(4);
  });

  it('reports progress inside the level', () => {
    expect(levelProgress(120)).toEqual({
      level: 2,
      levelStartXp: 50,
      nextLevelXp: 200,
      xpIntoLevel: 70,
      xpForLevel: 150,
    });
  });
});

describe('xp', () => {
  it('pays more for a homework photo than a typed question', () => {
    const o = { firstOfDay: false, streakAfter: 1, eventsToday: 3 };
    expect(xpFor('QUESTION', o).total).toBe(10);
    expect(xpFor('PHOTO', o).total).toBe(15);
  });

  it('adds the first-of-day and streak milestone bonuses once', () => {
    const first = xpFor('QUESTION', {
      firstOfDay: true,
      streakAfter: 3,
      eventsToday: 0,
    });
    expect(first).toEqual({ base: 10, firstOfDay: 10, streak: 20, total: 40 });
    const later = xpFor('QUESTION', {
      firstOfDay: false,
      streakAfter: 3,
      eventsToday: 1,
    });
    expect(later.total).toBe(10);
  });

  it('pays nothing after the daily cap', () => {
    const r = xpFor('QUESTION', {
      firstOfDay: false,
      streakAfter: 1,
      eventsToday: DAILY_XP_EVENT_CAP,
    });
    expect(r.total).toBe(0);
  });
});

describe('badges', () => {
  const facts = {
    questions: 0,
    photos: 0,
    voices: 0,
    streak: 0,
    bestStreak: 0,
    subjects: 0,
    level: 1,
  };

  it('has unique codes', () => {
    expect(new Set(BADGES.map((b) => b.code)).size).toBe(BADGES.length);
  });

  it('awards only badges not already held', () => {
    const got = newBadges({ ...facts, questions: 10, subjects: 1 }, [
      'first_question',
    ]).map((b) => b.code);
    expect(got).toEqual(['questions_10']);
  });

  it('keeps a streak badge once earned even if the streak later breaks', () => {
    const got = newBadges({ ...facts, streak: 0, bestStreak: 7 }, []).map(
      (b) => b.code,
    );
    expect(got).toEqual(expect.arrayContaining(['streak_3', 'streak_7']));
  });
});
