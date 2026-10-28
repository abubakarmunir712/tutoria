import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ProgressService } from './progress.service';

@UseGuards(JwtAuthGuard)
@Controller('me')
export class ProgressController {
  constructor(private readonly progress: ProgressService) {}

  // The parent dashboard: every child's XP, streak, week and badges in one call.
  @Get('progress')
  all(@CurrentUser() userId: string) {
    return this.progress.summariesFor(userId);
  }

  @Get('students/:id/progress')
  one(@CurrentUser() userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.progress.summaryFor(userId, id);
  }
}
