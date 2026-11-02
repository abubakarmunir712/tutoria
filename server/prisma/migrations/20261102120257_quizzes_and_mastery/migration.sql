-- CreateEnum
CREATE TYPE "QuizMode" AS ENUM ('QUIZ', 'CHECK');

-- CreateEnum
CREATE TYPE "QuestionLevel" AS ENUM ('FOUNDATIONAL', 'UNDERSTANDING', 'APPLICATION', 'REASONING', 'TRANSFER');

-- CreateEnum
CREATE TYPE "Verdict" AS ENUM ('CORRECT', 'PARTIAL', 'INCORRECT');

-- CreateEnum
CREATE TYPE "MasteryState" AS ENUM ('EMERGING', 'DEVELOPING', 'SECURE', 'MASTERED', 'NEEDS_REVISION');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "EventKind" ADD VALUE 'QUIZ';
ALTER TYPE "EventKind" ADD VALUE 'CHECK';
ALTER TYPE "EventKind" ADD VALUE 'ASSIGNMENT';

-- AlterEnum
ALTER TYPE "UsageKind" ADD VALUE 'GRADE';

-- AlterTable
ALTER TABLE "StudentStats" ADD COLUMN     "assignments" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "masteredTopics" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "perfectQuizzes" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "quizzes" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "QuizTopic" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "grade" "Grade" NOT NULL,
    "subject" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "strand" TEXT NOT NULL,
    "term" TEXT NOT NULL,
    "week" INTEGER NOT NULL,
    "order" INTEGER NOT NULL,
    "previousLearning" TEXT NOT NULL,
    "nextLearning" TEXT NOT NULL,
    "remediation" TEXT NOT NULL,
    "alternativeExplanation" TEXT NOT NULL,
    "prerequisiteRevision" TEXT NOT NULL,
    "likelyMisconception" TEXT NOT NULL,
    "assignmentTask" TEXT NOT NULL,
    "assignmentCriteria" TEXT NOT NULL,
    "assignmentReflection" TEXT NOT NULL,

    CONSTRAINT "QuizTopic_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QuizQuestion" (
    "id" TEXT NOT NULL,
    "topicId" TEXT NOT NULL,
    "order" INTEGER NOT NULL,
    "level" "QuestionLevel" NOT NULL,
    "difficulty" INTEGER NOT NULL,
    "question" TEXT NOT NULL,
    "expectedAnswer" TEXT NOT NULL,
    "variations" TEXT NOT NULL,
    "commonWrongAnswer" TEXT NOT NULL,
    "misconception" TEXT NOT NULL,
    "workedSolution" TEXT NOT NULL,
    "rubric" TEXT NOT NULL,
    "diagnostic" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "QuizQuestion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QuizAttempt" (
    "id" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "topicId" TEXT NOT NULL,
    "mode" "QuizMode" NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMP(3),
    "score" DOUBLE PRECISION,
    "xp" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "QuizAttempt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QuizAnswer" (
    "id" TEXT NOT NULL,
    "attemptId" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "answer" TEXT NOT NULL,
    "tries" INTEGER NOT NULL DEFAULT 1,
    "verdict" "Verdict" NOT NULL,
    "points" DOUBLE PRECISION NOT NULL,
    "feedback" TEXT NOT NULL DEFAULT '',
    "aiGraded" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QuizAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TopicMastery" (
    "studentId" TEXT NOT NULL,
    "topicId" TEXT NOT NULL,
    "state" "MasteryState" NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "bestScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "lastScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "strongAttempts" INTEGER NOT NULL DEFAULT 0,
    "lastAttemptAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TopicMastery_pkey" PRIMARY KEY ("studentId","topicId")
);

-- CreateTable
CREATE TABLE "AssignmentSubmission" (
    "id" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "topicId" TEXT NOT NULL,
    "response" TEXT NOT NULL,
    "reflection" TEXT NOT NULL DEFAULT '',
    "verdict" "Verdict" NOT NULL,
    "feedback" TEXT NOT NULL DEFAULT '',
    "xp" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AssignmentSubmission_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "QuizTopic_code_key" ON "QuizTopic"("code");

-- CreateIndex
CREATE INDEX "QuizTopic_grade_subject_order_idx" ON "QuizTopic"("grade", "subject", "order");

-- CreateIndex
CREATE UNIQUE INDEX "QuizQuestion_topicId_order_key" ON "QuizQuestion"("topicId", "order");

-- CreateIndex
CREATE INDEX "QuizAttempt_studentId_topicId_idx" ON "QuizAttempt"("studentId", "topicId");

-- CreateIndex
CREATE INDEX "QuizAttempt_finishedAt_idx" ON "QuizAttempt"("finishedAt");

-- CreateIndex
CREATE UNIQUE INDEX "QuizAnswer_attemptId_questionId_key" ON "QuizAnswer"("attemptId", "questionId");

-- CreateIndex
CREATE INDEX "TopicMastery_topicId_idx" ON "TopicMastery"("topicId");

-- CreateIndex
CREATE INDEX "AssignmentSubmission_studentId_topicId_idx" ON "AssignmentSubmission"("studentId", "topicId");

-- AddForeignKey
ALTER TABLE "QuizQuestion" ADD CONSTRAINT "QuizQuestion_topicId_fkey" FOREIGN KEY ("topicId") REFERENCES "QuizTopic"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuizAttempt" ADD CONSTRAINT "QuizAttempt_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuizAttempt" ADD CONSTRAINT "QuizAttempt_topicId_fkey" FOREIGN KEY ("topicId") REFERENCES "QuizTopic"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuizAnswer" ADD CONSTRAINT "QuizAnswer_attemptId_fkey" FOREIGN KEY ("attemptId") REFERENCES "QuizAttempt"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuizAnswer" ADD CONSTRAINT "QuizAnswer_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "QuizQuestion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopicMastery" ADD CONSTRAINT "TopicMastery_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TopicMastery" ADD CONSTRAINT "TopicMastery_topicId_fkey" FOREIGN KEY ("topicId") REFERENCES "QuizTopic"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AssignmentSubmission" ADD CONSTRAINT "AssignmentSubmission_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AssignmentSubmission" ADD CONSTRAINT "AssignmentSubmission_topicId_fkey" FOREIGN KEY ("topicId") REFERENCES "QuizTopic"("id") ON DELETE CASCADE ON UPDATE CASCADE;
