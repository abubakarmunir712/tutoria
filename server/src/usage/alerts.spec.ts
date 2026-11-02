import { costAlerts, type AlertInput } from './alerts';

const base: AlertInput = {
  costToday: 1,
  capUsd: 10,
  alertPercent: 80,
  dailyAverageBefore: 1,
  callsToday: 50,
  errorsToday: 0,
};
const ids = (i: Partial<AlertInput>) =>
  costAlerts({ ...base, ...i }).map((a) => a.id);

describe('costAlerts', () => {
  it('is quiet on a normal day', () => {
    expect(ids({})).toEqual([]);
  });
  it('warns before the cap is reached', () => {
    expect(ids({ costToday: 8.5 })).toContain('near-cap');
  });
  it('goes critical at the cap, not both', () => {
    const a = costAlerts({ ...base, costToday: 10, dailyAverageBefore: 9 });
    expect(a.map((x) => x.id)).toEqual(['cap-reached']);
    expect(a[0].level).toBe('critical');
  });
  it('has no cap alerts when the cap is off', () => {
    expect(ids({ capUsd: 0, costToday: 500, dailyAverageBefore: 400 })).toEqual(
      [],
    );
  });
  it('flags a spike against the previous week', () => {
    expect(ids({ costToday: 4, dailyAverageBefore: 1 })).toEqual(['spike']);
  });
  it('ignores a spike on tiny amounts or with no history', () => {
    expect(ids({ costToday: 0.3, dailyAverageBefore: 0.05 })).toEqual([]);
    expect(ids({ costToday: 6, dailyAverageBefore: 0 })).toEqual([]);
  });
  it('flags a high failure rate once there are enough calls', () => {
    expect(ids({ callsToday: 20, errorsToday: 6 })).toEqual(['failures']);
    expect(ids({ callsToday: 4, errorsToday: 4 })).toEqual([]);
  });
});
