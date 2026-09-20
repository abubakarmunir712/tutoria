import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { ImagesController } from './images.controller';

@Module({
  controllers: [ChatController, ImagesController],
  providers: [ChatService],
})
export class ChatModule {}
