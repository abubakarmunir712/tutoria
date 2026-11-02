import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UsageKind } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { estimateCost, Prices, pricesFromEnv } from './cost';
import { SettingsService } from './settings.service';

export function startOfUtcDay(now: Date): Date {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
}

@Injectable()
export class UsageService {
  private readonly logger = new Logger(UsageService.name);
  private readonly prices: Prices;

  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: SettingsService,
    config: ConfigService,
  ) {
    this.prices = pricesFromEnv((k) => config.get<string>(k));
  }

  /**
   * Throws 429 when the learner or the whole service is over today's limits. If the usage tables
   * themselves can't be read, the tutor stays available rather than locking every child out.
   */
  async checkAllowed(
    studentId: string | null,
    kind: UsageKind,
    now = new Date(),
  ) {
    try {
      const limits = await this.settings.limits();
      const since = startOfUtcDay(now);

      if (
        studentId &&
        limits.dailyQuestionLimit > 0 &&
        (kind === 'ASK' || kind === 'ASK_IMAGE')
      ) {
        const asked = await this.prisma.usageLog.count({
          where: {
            studentId,
            ok: true,
            kind: { in: ['ASK', 'ASK_IMAGE'] },
            createdAt: { gte: since },
          },
        });
        if (asked >= limits.dailyQuestionLimit) {
          throw new HttpException(
            "You've asked a lot of questions today. Great work! Come back tomorrow for more.",
            HttpStatus.TOO_MANY_REQUESTS,
          );
        }
      }

      if (studentId && limits.dailyMarkingLimit > 0 && kind === 'GRADE') {
        const marked = await this.prisma.usageLog.count({
          where: {
            studentId,
            ok: true,
            kind: 'GRADE',
            createdAt: { gte: since },
          },
        });
        if (marked >= limits.dailyMarkingLimit) {
          throw new HttpException(
            'Marking limit reached for today.',
            HttpStatus.TOO_MANY_REQUESTS,
          );
        }
      }

      if (limits.dailyCostCapUsd > 0) {
        const spent = await this.prisma.usageLog.aggregate({
          where: { createdAt: { gte: since } },
          _sum: { costUsd: true },
        });
        if ((spent._sum.costUsd ?? 0) >= limits.dailyCostCapUsd) {
          throw new HttpException(
            'The tutor is taking a short rest. Please try again tomorrow.',
            HttpStatus.TOO_MANY_REQUESTS,
          );
        }
      }
    } catch (e) {
      if (e instanceof HttpException) throw e;
      this.logger.warn(`Could not check usage limits: ${String(e)}`);
    }
  }

  /** Record an AI call. Never throws: losing a log line must not fail a child's question. */
  async log(entry: {
    studentId: string | null;
    kind: UsageKind;
    subject?: string;
    inputChars: number;
    outputChars: number;
    ok: boolean;
    durationMs: number;
  }) {
    try {
      await this.prisma.usageLog.create({
        data: {
          ...entry,
          costUsd: entry.ok
            ? estimateCost(
                entry.kind,
                entry.inputChars,
                entry.outputChars,
                this.prices,
              )
            : 0,
        },
      });
    } catch (e) {
      this.logger.warn(`Could not record usage: ${String(e)}`);
    }
  }
}
