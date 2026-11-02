import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import {
  AnswerDto,
  OverviewQuery,
  StartAttemptDto,
  StudentQuery,
  SubmitAssignmentDto,
  TopicsQuery,
} from './dto';
import { QuizService } from './quiz.service';

@UseGuards(JwtAuthGuard)
@Controller('quiz')
export class QuizController {
  constructor(private readonly quiz: QuizService) {}

  // The practice units for a learner's class and subject, with their mastery.
  @Get('topics')
  topics(@CurrentUser() userId: string, @Query() q: TopicsQuery) {
    return this.quiz.topics(userId, q.studentId, q.subject);
  }

  // Mastery across all subjects: for one learner, or every learner of this login.
  @Get('overview')
  overview(@CurrentUser() userId: string, @Query() q: OverviewQuery) {
    return this.quiz.overview(userId, q.studentId);
  }

  @Post('attempts')
  start(@CurrentUser() userId: string, @Body() dto: StartAttemptDto) {
    return this.quiz.start(userId, dto);
  }

  @Get('attempts/:id')
  attempt(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.quiz.get(userId, id);
  }

  @Post('attempts/:id/answer')
  answer(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AnswerDto,
  ) {
    return this.quiz.answer(userId, id, dto);
  }

  @Get('topics/:topicId/assignment')
  assignment(
    @CurrentUser() userId: string,
    @Param('topicId', ParseUUIDPipe) topicId: string,
    @Query() q: StudentQuery,
  ) {
    return this.quiz.assignment(userId, q.studentId, topicId);
  }

  @Post('topics/:topicId/assignment')
  submit(
    @CurrentUser() userId: string,
    @Param('topicId', ParseUUIDPipe) topicId: string,
    @Body() dto: SubmitAssignmentDto,
  ) {
    return this.quiz.submitAssignment(userId, topicId, dto);
  }
}
