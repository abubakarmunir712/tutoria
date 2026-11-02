import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class AskImageDto {
  @IsOptional()
  @IsString()
  grade?: string;

  @IsOptional()
  @IsString()
  subject?: string;

  @IsOptional()
  @IsUUID()
  studentId?: string;

  @IsOptional()
  @IsUUID()
  conversationId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  topic?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  topK?: number;

  // Prior turns as a JSON string (multipart forms carry strings only), same shape as
  // AskDto.history: [{"role": "user" | "assistant", "content": "..."}]. The AI service
  // ignores a value it can't parse.
  @IsOptional()
  @IsString()
  @MaxLength(20000)
  history?: string;
}
