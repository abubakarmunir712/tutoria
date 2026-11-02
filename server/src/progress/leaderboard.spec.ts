import { publicName, rankBoard, weekStart } from './leaderboard';

describe('publicName', () => {
  it('keeps a first name and last initial', () => {
    expect(publicName('Ama Serwaa Mensah')).toBe('Ama M.');
    expect(publicName('  kofi  boateng ')).toBe('kofi B.');
  });
  it('copes with one name or none', () => {
    expect(publicName('Ama')).toBe('Ama');
    expect(publicName('  ')).toBe('Learner');
  });
});

describe('weekStart', () => {
  it('is the Monday of the week, in UTC', () => {
    expect(weekStart(new Date('2026-11-04T15:00:00Z')).toISOString()).toBe(
      '2026-11-02T00:00:00.000Z',
    );
    expect(weekStart(new Date('2026-11-08T23:59:00Z')).toISOString()).toBe(
      '2026-11-02T00:00:00.000Z',
    );
    expect(weekStart(new Date('2026-11-02T00:00:00Z')).toISOString()).toBe(
      '2026-11-02T00:00:00.000Z',
    );
  });
});

describe('rankBoard', () => {
  const row = (id: string, xp: number) => ({
    studentId: id,
    name: id.toUpperCase(),
    xp,
  });
  it('ranks by XP and shares a rank on a tie', () => {
    const { top } = rankBoard([row('a', 10), row('b', 30), row('c', 10)], 'x');
    expect(top.map((r) => [r.studentId, r.rank])).toEqual([
      ['b', 1],
      ['a', 2],
      ['c', 2],
    ]);
  });
  it('shows the learner their own row when they are outside the top', () => {
    const many = Array.from({ length: 14 }, (_, i) => row(`s${i}`, 100 - i));
    const { top, you } = rankBoard(many, 's12');
    expect(top).toHaveLength(10);
    expect(you).toMatchObject({ studentId: 's12', rank: 13, isYou: true });
  });
  it('does not repeat the learner when they are already in the top', () => {
    const { top, you } = rankBoard([row('a', 5), row('b', 9)], 'a');
    expect(you).toBeNull();
    expect(top.find((r) => r.isYou)?.studentId).toBe('a');
  });
});
