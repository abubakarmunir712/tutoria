import { IsEnum, IsOptional } from 'class-validator';
import { Grade } from '@prisma/client';

export class UpdateProfileDto {
  @IsOptional()
  @IsEnum(Grade)
  grade?: Grade;
}
