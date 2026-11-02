import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './admin.guard';
import { DaysQuery, StudentsQuery, UpdateLimitsDto } from './admin.dto';
import { AdminService } from './admin.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('me')
  me(@CurrentUser() userId: string) {
    return this.admin.me(userId);
  }

  @Get('overview')
  overview() {
    return this.admin.overview();
  }

  @Get('usage')
  usage(@Query() q: DaysQuery) {
    return this.admin.usage(q.days);
  }

  @Get('learning')
  learning(@Query() q: DaysQuery) {
    return this.admin.learning(q.days);
  }

  @Get('students')
  students(@Query() q: StudentsQuery) {
    return this.admin.students(q);
  }

  @Get('settings')
  settings() {
    return this.admin.limits();
  }

  @Put('settings')
  updateSettings(@Body() dto: UpdateLimitsDto) {
    return this.admin.setLimits(dto);
  }
}
