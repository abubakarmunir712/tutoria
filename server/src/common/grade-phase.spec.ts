import { Grade, Phase } from '@prisma/client';
import { phaseForGrade } from './grade-phase';

describe('phaseForGrade', () => {
  it.each([
    [Grade.B4, Phase.UPPER_PRIMARY],
    [Grade.B5, Phase.UPPER_PRIMARY],
    [Grade.B6, Phase.UPPER_PRIMARY],
    [Grade.B7, Phase.JHS],
    [Grade.B8, Phase.JHS],
    [Grade.B9, Phase.JHS],
    [Grade.SHS1, Phase.SHS],
    [Grade.SHS2, Phase.SHS],
    [Grade.SHS3, Phase.SHS],
  ])('%s is in %s', (grade, phase) => {
    expect(phaseForGrade(grade)).toBe(phase);
  });

  it('covers every grade in the schema', () => {
    for (const grade of Object.values(Grade)) {
      expect(Object.values(Phase)).toContain(phaseForGrade(grade));
    }
  });
});
