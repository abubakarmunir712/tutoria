-- CreateEnum
CREATE TYPE "EventKind" AS ENUM ('QUESTION', 'PHOTO', 'VOICE');

-- CreateEnum
CREATE TYPE "UsageKind" AS ENUM ('ASK', 'ASK_IMAGE', 'TRANSCRIBE', 'SPEAK');

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "isAdmin" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "LearningEvent" (
    "id" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "kind" "EventKind" NOT NULL,
    "subject" TEXT NOT NULL,
    "topic" TEXT,
    "xp" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LearningEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StudentStats" (
    "studentId" TEXT NOT NULL,
    "xp" INTEGER NOT NULL DEFAULT 0,
    "questions" INTEGER NOT NULL DEFAULT 0,
    "photos" INTEGER NOT NULL DEFAULT 0,
    "voices" INTEGER NOT NULL DEFAULT 0,
    "streak" INTEGER NOT NULL DEFAULT 0,
    "bestStreak" INTEGER NOT NULL DEFAULT 0,
    "lastActiveDay" TEXT,
    "lastSubject" TEXT,
    "lastTopic" TEXT,
    "lastActiveAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StudentStats_pkey" PRIMARY KEY ("studentId")
);

-- CreateTable
CREATE TABLE "StudentBadge" (
    "id" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "earnedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StudentBadge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UsageLog" (
    "id" TEXT NOT NULL,
    "studentId" TEXT,
    "kind" "UsageKind" NOT NULL,
    "subject" TEXT,
    "inputChars" INTEGER NOT NULL DEFAULT 0,
    "outputChars" INTEGER NOT NULL DEFAULT 0,
    "costUsd" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "ok" BOOLEAN NOT NULL DEFAULT true,
    "durationMs" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UsageLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Setting" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Setting_pkey" PRIMARY KEY ("key")
);

-- CreateIndex
CREATE INDEX "LearningEvent_studentId_createdAt_idx" ON "LearningEvent"("studentId", "createdAt");

-- CreateIndex
CREATE INDEX "LearningEvent_createdAt_idx" ON "LearningEvent"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "StudentBadge_studentId_code_key" ON "StudentBadge"("studentId", "code");

-- CreateIndex
CREATE INDEX "UsageLog_createdAt_idx" ON "UsageLog"("createdAt");

-- CreateIndex
CREATE INDEX "UsageLog_studentId_createdAt_idx" ON "UsageLog"("studentId", "createdAt");

-- AddForeignKey
ALTER TABLE "LearningEvent" ADD CONSTRAINT "LearningEvent_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StudentStats" ADD CONSTRAINT "StudentStats_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StudentBadge" ADD CONSTRAINT "StudentBadge_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UsageLog" ADD CONSTRAINT "UsageLog_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE SET NULL ON UPDATE CASCADE;
