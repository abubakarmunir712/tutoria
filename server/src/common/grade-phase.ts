import { Grade, Phase } from '@prisma/client';

/** The curriculum phase a grade belongs to (B4-B6 Upper Primary, B7-B9 JHS, SHS 1-3). */
export function phaseForGrade(grade: Grade): Phase {
  switch (grade) {
    case Grade.B4:
    case Grade.B5:
    case Grade.B6:
      return Phase.UPPER_PRIMARY;
    case Grade.B7:
    case Grade.B8:
    case Grade.B9:
      return Phase.JHS;
    default:
      return Phase.SHS;
  }
}
