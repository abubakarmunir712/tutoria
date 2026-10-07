import { Grade, SchoolType } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsOptional, IsString, Length } from 'class-validator';

export class CreateStudentDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(1, 60)
  name: string;

  @IsEnum(Grade)
  grade: Grade;

  @IsOptional()
  @IsEnum(SchoolType)
  schoolType?: SchoolType;
}
