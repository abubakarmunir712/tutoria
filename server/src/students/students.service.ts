import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Grade, UserRole } from '@prisma/client';
import { phaseForGrade } from '../common/grade-phase';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';

const studentInclude = {
  enrollments: { include: { subject: true } },
} as const;

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  /** The signed-in user with their learner profiles (children, or their own). */
  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        students: {
          include: studentInclude,
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  /** Subjects offered for a grade's phase, or every subject when no grade is given. */
  listSubjects(grade?: Grade) {
    return this.prisma.subject.findMany({
      where: grade ? { phase: phaseForGrade(grade) } : undefined,
      orderBy: { name: 'asc' },
    });
  }

  async createStudent(userId: string, dto: CreateStudentDto) {
    await this.requireParent(userId, 'Only parent accounts can add children');
    return this.prisma.student.create({
      data: {
        userId,
        name: dto.name,
        grade: dto.grade,
        schoolType: dto.schoolType,
      },
      include: studentInclude,
    });
  }

  async updateStudent(
    userId: string,
    studentId: string,
    dto: UpdateStudentDto,
  ) {
    const student = await this.owned(userId, studentId);
    const phaseChanged =
      dto.grade !== undefined &&
      (!student.grade ||
        phaseForGrade(dto.grade) !== phaseForGrade(student.grade));

    return this.prisma.$transaction(async (tx) => {
      if (phaseChanged && dto.grade) {
        // Moving to a new phase (Class 6 -> JHS 1): subjects that don't exist there go.
        await tx.enrollment.deleteMany({
          where: {
            studentId,
            subject: { phase: { not: phaseForGrade(dto.grade) } },
          },
        });
      }
      return tx.student.update({
        where: { id: studentId },
        data: dto,
        include: studentInclude,
      });
    });
  }

  async deleteStudent(userId: string, studentId: string) {
    await this.requireParent(
      userId,
      'Only parent accounts can remove children',
    );
    await this.owned(userId, studentId);
    await this.prisma.student.delete({ where: { id: studentId } });
  }

  /** Replace the subjects a learner studies. Every subject must exist in their phase. */
  async setSubjects(userId: string, studentId: string, subjectIds: string[]) {
    const student = await this.owned(userId, studentId);
    if (!student.grade) {
      throw new BadRequestException('Choose a class before choosing subjects');
    }
    const phase = phaseForGrade(student.grade);

    const subjects = await this.prisma.subject.findMany({
      where: { id: { in: subjectIds } },
    });
    if (subjects.length !== subjectIds.length) {
      throw new BadRequestException('Unknown subject');
    }
    if (subjects.some((s) => s.phase !== phase)) {
      throw new BadRequestException('A subject is not taught in this class');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.enrollment.deleteMany({
        where: { studentId, subjectId: { notIn: subjectIds } },
      });
      await tx.enrollment.createMany({
        data: subjectIds.map((subjectId) => ({ studentId, subjectId })),
        skipDuplicates: true,
      });
      return tx.student.findUniqueOrThrow({
        where: { id: studentId },
        include: studentInclude,
      });
    });
  }

  /** The learner, if (and only if) it belongs to this user — otherwise it "doesn't exist". */
  private async owned(userId: string, studentId: string) {
    const student = await this.prisma.student.findFirst({
      where: { id: studentId, userId },
    });
    if (!student) {
      throw new NotFoundException('Student not found');
    }
    return student;
  }

  private async requireParent(userId: string, message: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });
    if (user?.role !== UserRole.PARENT) {
      throw new ForbiddenException(message);
    }
  }
}
