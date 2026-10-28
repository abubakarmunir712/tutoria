import { Module } from '@nestjs/common';
import { ProgressController } from '../progress/progress.controller';
import { ProgressService } from '../progress/progress.service';
import { SettingsService } from '../usage/settings.service';
import { UsageService } from '../usage/usage.service';

/** What the tutor remembers about each learner (XP, streaks, badges) and about each AI call
 *  (cost, rate limits). Used by chat to record activity and by admin to report on it. */
@Module({
  controllers: [ProgressController],
  providers: [ProgressService, UsageService, SettingsService],
  exports: [ProgressService, UsageService, SettingsService],
})
export class TrackingModule {}
