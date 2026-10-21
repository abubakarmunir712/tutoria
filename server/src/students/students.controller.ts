import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseFilePipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { Grade } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { StudentsService } from './students.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { SetSubjectsDto } from './dto/set-subjects.dto';
import { ImageFileValidator } from '../chat/validators/image-file.validator';

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

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

  // Profile picture: JPEG/PNG/WebP, up to 5 MB, stored on the server's disk.
  @Put('students/:id/photo')
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: MAX_PHOTO_BYTES } }),
  )
  setPhoto(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile(new ParseFilePipe({ validators: [new ImageFileValidator()] }))
    file: Express.Multer.File,
  ) {
    return this.students.setPhoto(
      userId,
      id,
      file.buffer,
      sniffMime(file.buffer),
    );
  }

  @Get('students/:id/photo')
  async getPhoto(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Res() res: Response,
  ) {
    const { bytes, mime } = await this.students.getPhoto(userId, id);
    res.setHeader('Content-Type', mime);
    res.setHeader('Cache-Control', 'private, max-age=86400');
    res.send(bytes);
  }

  @Delete('students/:id/photo')
  removePhoto(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.students.removePhoto(userId, id);
  }
}

/** The type of an already-validated image, from its leading bytes (not the client's claim). */
function sniffMime(b: Buffer) {
  if (b[0] === 0xff) return 'image/jpeg';
  if (b[0] === 0x89) return 'image/png';
  return 'image/webp';
}
