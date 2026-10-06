import {
  IsInt,
  IsOptional,
  IsString,
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
