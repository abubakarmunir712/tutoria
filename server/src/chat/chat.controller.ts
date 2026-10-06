import {
  Body,
  Controller,
  ParseFilePipe,
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
import { ImageFileValidator } from './validators/image-file.validator';

const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Post('ask')
  ask(@Body() dto: AskDto) {
    return this.chat.ask(dto);
  }

  // Homework photos: JPEG/PNG/WebP only (the app sends downscaled JPEGs), capped at 10 MB —
  // a missing or wrong-type file is a 400 here rather than a crash further down.
  @Post('ask-image')
  @UseInterceptors(
    FileInterceptor('image', { limits: { fileSize: MAX_IMAGE_BYTES } }),
  )
  askImage(
    @Body() dto: AskImageDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [new ImageFileValidator()],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.chat.askImage(dto, file);
  }
}
