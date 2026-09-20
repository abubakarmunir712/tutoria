import {
  Body,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ChatService } from './chat.service';
import { AskDto } from './dto/ask.dto';
import { AskImageDto } from './dto/ask-image.dto';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Post('ask')
  ask(@Body() dto: AskDto) {
    return this.chat.ask(dto);
  }

  @Post('ask-image')
  @UseInterceptors(FileInterceptor('image'))
  askImage(
    @Body() dto: AskImageDto,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.chat.askImage(dto, file);
  }
}
