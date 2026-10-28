import { IsOptional, IsUUID } from 'class-validator';

export class TranscribeDto {
  // Which learner is speaking, so the cost of transcribing is attributed to them.
  @IsOptional()
  @IsUUID()
  studentId?: string;
}
