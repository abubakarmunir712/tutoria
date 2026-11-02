import { Module } from '@nestjs/common';
import { TrackingModule } from '../tracking/tracking.module';
import { QuizController } from './quiz.controller';
import { QuizMarker } from './quiz-marker.service';
import { QuizService } from './quiz.service';

@Module({
  imports: [TrackingModule],
  controllers: [QuizController],
  providers: [QuizService, QuizMarker],
})
export class QuizModule {}
