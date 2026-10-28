import { Global, Module } from '@nestjs/common';
import { PrismaService } from '../../src/prisma/prisma.service';

// For tests that exercise the HTTP layer without a database: the usage log and rate-limit
// lookups that chat now does get empty answers (no limits set, nothing spent yet).
const stub = {
  setting: { findMany: () => Promise.resolve([]) },
  usageLog: {
    count: () => Promise.resolve(0),
    aggregate: () => Promise.resolve({ _sum: { costUsd: 0 } }),
    create: () => Promise.resolve({}),
  },
};

@Global()
@Module({
  providers: [{ provide: PrismaService, useValue: stub }],
  exports: [PrismaService],
})
export class StubPrismaModule {}
