import { Module } from '@nestjs/common';
import { StudentsService } from './students.service';
import { StudentsController } from './students.controller';
import { PhotoStorage } from './photo-storage.service';

@Module({
  providers: [StudentsService, PhotoStorage],
  controllers: [StudentsController],
})
export class StudentsModule {}
