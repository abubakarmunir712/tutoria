import { IsUUID } from 'class-validator';

export class EnrollDto {
  @IsUUID()
  subjectId: string;
}
