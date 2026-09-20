import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentStudent } from '../auth/decorators/current-student.decorator';
import { StudentsService } from './students.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { EnrollDto } from './dto/enroll.dto';

@UseGuards(JwtAuthGuard)
@Controller('me')
export class StudentsController {
  constructor(private readonly students: StudentsService) {}

  @Get('profile')
  getProfile(@CurrentStudent() studentId: string) {
    return this.students.getProfile(studentId);
  }

  @Patch('profile')
  updateProfile(
    @CurrentStudent() studentId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.students.updateProfile(studentId, dto);
  }

  @Get('subjects')
  listSubjects() {
    return this.students.listSubjects();
  }

  @Post('enrollments')
  enroll(@CurrentStudent() studentId: string, @Body() dto: EnrollDto) {
    return this.students.enroll(studentId, dto.subjectId);
  }

  @Delete('enrollments/:subjectId')
  unenroll(
    @CurrentStudent() studentId: string,
    @Param('subjectId') subjectId: string,
  ) {
    return this.students.unenroll(studentId, subjectId);
  }
}
