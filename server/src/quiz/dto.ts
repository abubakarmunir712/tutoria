import { QuizMode } from '@prisma/client';
import {
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
} from 'class-validator';

export class TopicsQuery {
  @IsUUID()
  studentId: string;

  @IsString()
  @Length(1, 60)
  subject: string;
}

export class OverviewQuery {
  @IsOptional()
  @IsUUID()
  studentId?: string;
}

export class StudentQuery {
  @IsUUID()
  studentId: string;
}

export class StartAttemptDto {
  @IsUUID()
  studentId: string;

  @IsUUID()
  topicId: string;

  @IsEnum(QuizMode)
  mode: QuizMode;
}

export class AnswerDto {
  @IsUUID()
  questionId: string;

  @IsString()
  @Length(1, 600)
  answer: string;
}

export class SubmitAssignmentDto {
  @IsUUID()
  studentId: string;

  @IsString()
  @Length(1, 4000)
  response: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  reflection?: string;
}
