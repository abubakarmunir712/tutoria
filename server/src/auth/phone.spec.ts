import { normalizePhone } from './phone';

describe('normalizePhone', () => {
  it.each([
    ['+233241234567', '+233241234567'],
    ['0241234567', '+233241234567'],
    ['024 123 4567', '+233241234567'],
    ['024-123-4567', '+233241234567'],
    ['233241234567', '+233241234567'],
    ['  +233 24 123 4567 ', '+233241234567'],
  ])('reads %p as %p', (input, expected) => {
    expect(normalizePhone(input)).toBe(expected);
  });

  it('keeps numbers from other countries', () => {
    expect(normalizePhone('+447911123456')).toBe('+447911123456');
  });

  it.each(['', '12345', 'abc', '+233', '024123'])('rejects %p', (input) => {
    expect(normalizePhone(input)).toBeNull();
  });
});
