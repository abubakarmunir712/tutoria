import {
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ProgressService } from '../progress/progress.service';
import { ConversationsService } from './conversations.service';

/** A learner's saved tutor conversations. Parents can open their children's. */
@UseGuards(JwtAuthGuard)
@Controller('me/students/:studentId/conversations')
export class ConversationsController {
  constructor(
    private readonly conversations: ConversationsService,
    private readonly progress: ProgressService,
  ) {}

  @Get()
  async list(
    @CurrentUser() userId: string,
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @Query('subject') subject?: string,
  ) {
    await this.progress.requireOwned(userId, studentId);
    return this.conversations.list(studentId, subject);
  }

  @Get(':id')
  async one(
    @CurrentUser() userId: string,
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.progress.requireOwned(userId, studentId);
    return this.conversations.get(studentId, id);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(
    @CurrentUser() userId: string,
    @Param('studentId', ParseUUIDPipe) studentId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.progress.requireOwned(userId, studentId);
    await this.conversations.remove(studentId, id);
  }
}
