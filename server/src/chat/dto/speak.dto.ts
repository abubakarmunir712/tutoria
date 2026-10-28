import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class SpeakDto {
  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  text: string;

  // Which learner is listening, so the cost of the speech is attributed to them.
  @IsOptional()
  @IsUUID()
  studentId?: string;
}
