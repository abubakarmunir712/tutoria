import { titleFrom } from './conversations.service';

describe('titleFrom', () => {
  it('uses the question, tidied', () => {
    expect(titleFrom('  What is\n a   fraction? ')).toBe('What is a fraction?');
  });
  it('shortens a long question', () => {
    const t = titleFrom('a'.repeat(200));
    expect(t.length).toBe(80);
    expect(t.endsWith('…')).toBe(true);
  });
  it('names a photo-only message', () => {
    expect(titleFrom('')).toBe('Homework photo');
  });
});
