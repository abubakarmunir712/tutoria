import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
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
}
