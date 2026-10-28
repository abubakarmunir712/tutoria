import { estimateCost, pricesFromEnv } from './cost';

const p = pricesFromEnv(() => undefined);

describe('estimateCost', () => {
  it('prices a typical question at a fraction of a cent', () => {
    const c = estimateCost('ASK', 200, 1200, p);
    expect(c).toBeGreaterThan(0.0005);
    expect(c).toBeLessThan(0.01);
  });

  it('costs more for a longer answer and for a photo', () => {
    expect(estimateCost('ASK', 200, 3000, p)).toBeGreaterThan(
      estimateCost('ASK', 200, 300, p),
    );
    expect(estimateCost('ASK_IMAGE', 200, 300, p)).toBeGreaterThan(
      estimateCost('ASK', 200, 300, p),
    );
  });

  it('prices speech by length and transcription per call', () => {
    expect(estimateCost('SPEAK', 1000, 0, p)).toBeCloseTo(0.015, 6);
    expect(estimateCost('TRANSCRIBE', 0, 0, p)).toBe(0.003);
  });

  it('reads overrides from the environment', () => {
    const custom = pricesFromEnv((k) =>
      k === 'PRICE_STT_PER_CALL' ? '0.01' : undefined,
    );
    expect(estimateCost('TRANSCRIBE', 0, 0, custom)).toBe(0.01);
  });
});
