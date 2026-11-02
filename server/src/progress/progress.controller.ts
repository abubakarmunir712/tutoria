import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Put,
  UseGuards,
} from '@nestjs/common';
import { IsBoolean } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ProgressService } from './progress.service';

class LeaderboardVisibilityDto {
  @IsBoolean()
  visible: boolean;
}

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

  // This week's class board (same grade): first name and initial, XP, and the learner's own row.
  @Get('students/:id/leaderboard')
  board(@CurrentUser() userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.progress.leaderboard(userId, id);
  }

  @Put('students/:id/leaderboard')
  setBoardVisible(
    @CurrentUser() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: LeaderboardVisibilityDto,
  ) {
    return this.progress.setLeaderboardVisible(userId, id, dto.visible);
  }
}
