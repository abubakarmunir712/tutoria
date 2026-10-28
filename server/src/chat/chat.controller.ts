import {
  Body,
  Controller,
  ParseFilePipe,
  Post,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ChatService } from './chat.service';
import { AskDto } from './dto/ask.dto';
import { AskImageDto } from './dto/ask-image.dto';
import { SpeakDto } from './dto/speak.dto';
import { TranscribeDto } from './dto/transcribe.dto';
import { AudioFileValidator } from './validators/audio-file.validator';
import { ImageFileValidator } from './validators/image-file.validator';

const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_AUDIO_BYTES = 10 * 1024 * 1024;

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Post('ask')
  ask(@CurrentUser() userId: string, @Body() dto: AskDto) {
    return this.chat.ask(userId, dto);
  }

  // Homework photos: JPEG/PNG/WebP only (the app sends downscaled JPEGs), capped at 10 MB —
  // a missing or wrong-type file is a 400 here rather than a crash further down.
  @Post('ask-image')
  @UseInterceptors(
    FileInterceptor('image', { limits: { fileSize: MAX_IMAGE_BYTES } }),
  )
  askImage(
    @CurrentUser() userId: string,
    @Body() dto: AskImageDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [new ImageFileValidator()],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.chat.askImage(userId, dto, file);
  }

  // Voice in: a spoken question becomes text. The app shows it and sends it through
  // /chat/ask like a typed message, so voice questions are grounded the same way.
  @Post('transcribe')
  @UseInterceptors(
    FileInterceptor('audio', { limits: { fileSize: MAX_AUDIO_BYTES } }),
  )
  transcribe(
    @CurrentUser() userId: string,
    @Body() dto: TranscribeDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [new AudioFileValidator()],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.chat.transcribe(userId, dto.studentId, file);
  }

  // Voice out: a tutor reply becomes audio the app plays.
  @Post('speak')
  async speak(
    @CurrentUser() userId: string,
    @Body() dto: SpeakDto,
    @Res() res: Response,
  ) {
    const { audio, mimeType } = await this.chat.speak(
      userId,
      dto.studentId,
      dto.text,
    );
    res.setHeader('Content-Type', mimeType);
    res.send(audio);
  }
}
