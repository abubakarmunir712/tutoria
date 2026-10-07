import { ArrayMaxSize, ArrayUnique, IsArray, IsUUID } from 'class-validator';

export class SetSubjectsDto {
  @IsArray()
  @ArrayMaxSize(10)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  subjectIds: string[];
}
