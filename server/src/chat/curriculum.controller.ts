import {
  Controller,
  Get,
  NotFoundException,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Grade } from '@prisma/client';
import { IsEnum, IsString, Length } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ChatService } from './chat.service';

class TopicsQuery {
  @IsEnum(Grade)
  grade: Grade;

  @IsString()
  @Length(1, 60)
  subject: string;
}

@UseGuards(JwtAuthGuard)
@Controller('curriculum')
export class CurriculumController {
  constructor(private readonly chat: ChatService) {}

  // The curriculum's strands and topics for a grade and subject, in curriculum order.
  @Get('topics')
  async topics(@Query() query: TopicsQuery) {
    const topics = await this.chat.topics(query.grade, query.subject);
    if (!topics) {
      throw new NotFoundException('No topics for this grade and subject');
    }
    return topics;
  }
}
