import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  async getProfile(studentId: string) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      include: { enrollments: { include: { subject: true } } },
    });
    if (!student) {
      throw new NotFoundException('Student not found');
    }
    const { passwordHash: _passwordHash, ...profile } = student;
    return profile;
  }

  async updateProfile(studentId: string, dto: UpdateProfileDto) {
    const student = await this.prisma.student.update({
      where: { id: studentId },
      data: dto,
    });
    const { passwordHash: _passwordHash, ...profile } = student;
    return profile;
  }

  async enroll(studentId: string, subjectId: string) {
    return this.prisma.enrollment.upsert({
      where: { studentId_subjectId: { studentId, subjectId } },
      create: { studentId, subjectId },
      update: {},
    });
  }

  async unenroll(studentId: string, subjectId: string) {
    return this.prisma.enrollment.delete({
      where: { studentId_subjectId: { studentId, subjectId } },
    });
  }

  listSubjects() {
    return this.prisma.subject.findMany();
  }
}
