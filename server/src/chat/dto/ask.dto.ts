import {
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { HistoryTurnDto } from './history-turn.dto';

export class AskDto {
  @IsString()
  question: string;

  @IsOptional()
  @IsString()
  grade?: string;

  @IsOptional()
  @IsString()
  subject?: string;

  // Which learner is asking. When given, the question earns that learner XP and counts toward
  // their streak and daily limit; the learner must belong to the signed-in user.
  @IsOptional()
  @IsUUID()
  studentId?: string;

  // The topic being studied, when the question came from the topic list.
  @IsOptional()
  @IsString()
  @MaxLength(120)
  topic?: string;

  // Whether the question was spoken (the app transcribes it first, then asks as text).
  @IsOptional()
  @IsIn(['text', 'voice'])
  via?: 'text' | 'voice';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  topK?: number;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => HistoryTurnDto)
  history?: HistoryTurnDto[];
}
