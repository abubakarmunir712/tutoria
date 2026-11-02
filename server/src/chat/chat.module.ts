import { Module } from '@nestjs/common';
import { TrackingModule } from '../tracking/tracking.module';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ImagesController } from './images.controller';
import { CurriculumController } from './curriculum.controller';

@Module({
  imports: [TrackingModule],
  controllers: [
    ChatController,
    ImagesController,
    CurriculumController,
    ConversationsController,
  ],
  providers: [ChatService, ConversationsService],
})
export class ChatModule {}
