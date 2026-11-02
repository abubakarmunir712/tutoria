import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** The rate limits an admin can change. 0 switches a limit off. */
export interface Limits {
  /** AI questions (typed, spoken or photo) one learner can ask per day */
  dailyQuestionLimit: number;
  /** estimated AI spend, in USD, across everyone per day before the tutor pauses */
  dailyCostCapUsd: number;
  /** AI-marked quiz answers and assignments one learner can have marked per day; past this
   *  the offline check marks instead, so practice keeps working */
  dailyMarkingLimit: number;
  /** percent of the daily cost cap at which the admin dashboard warns */
  costAlertPercent: number;
}

export const DEFAULT_LIMITS: Limits = {
  dailyQuestionLimit: 100,
  dailyCostCapUsd: 10,
  dailyMarkingLimit: 150,
  costAlertPercent: 80,
};

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async limits(): Promise<Limits> {
    const rows = await this.prisma.setting.findMany();
    const byKey = new Map(rows.map((r) => [r.key, r.value]));
    const read = (key: keyof Limits) => {
      const n = Number(byKey.get(key));
      return byKey.has(key) && Number.isFinite(n) && n >= 0
        ? n
        : DEFAULT_LIMITS[key];
    };
    return {
      dailyQuestionLimit: read('dailyQuestionLimit'),
      dailyCostCapUsd: read('dailyCostCapUsd'),
      dailyMarkingLimit: read('dailyMarkingLimit'),
      costAlertPercent: read('costAlertPercent'),
    };
  }

  async setLimits(next: Partial<Limits>): Promise<Limits> {
    for (const key of Object.keys(DEFAULT_LIMITS) as (keyof Limits)[]) {
      const value = next[key];
      if (value === undefined) continue;
      await this.prisma.setting.upsert({
        where: { key },
        create: { key, value: String(value) },
        update: { value: String(value) },
      });
    }
    return this.limits();
  }
}
