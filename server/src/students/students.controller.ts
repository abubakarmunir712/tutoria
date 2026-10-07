import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Grade } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { StudentsService } from './students.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { SetSubjectsDto } from './dto/set-subjects.dto';

class SubjectsQuery {
  @IsOptional()
  @IsEnum(Grade)
  grade?: Grade;
}

@UseGuards(JwtAuthGuard)
@Controller('me')
export class StudentsController {
  constructor(private readonly students: StudentsService) {}

  @Get()
  getMe(@CurrentUser() userId: string) {
    return this.students.getMe(userId);
  }

  @Get('subjects')
  listSubjects(@Query() query: SubjectsQuery) {
    return this.students.listSubjects(query.grade);
  }

  @Post('students')
  createStudent(@CurrentUser() userId: string, @Body() dto: CreateStudentDto) {
    return this.students.createStudent(userId, dto);
  }

  @Patch('students/:id')
  updateStudent(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateStudentDto,
  ) {
    return this.students.updateStudent(userId, id, dto);
  }

  @Delete('students/:id')
  @HttpCode(204)
  async deleteStudent(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.students.deleteStudent(userId, id);
  }

  @Put('students/:id/subjects')
  setSubjects(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetSubjectsDto,
  ) {
    return this.students.setSubjects(userId, id, dto.subjectIds);
  }
}
