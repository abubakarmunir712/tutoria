import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Grade, PrismaClient, QuestionLevel } from '@prisma/client';

// Loads prisma/data/quiz-bank.json (built by scripts/build_quiz_bank.py) into the database.
// Safe to run again: units and questions are matched by code / position and updated in place,
// so learners' attempts and mastery are kept.

interface BankQuestion {
  order: number;
  level: QuestionLevel;
  difficulty: number;
  question: string;
  expectedAnswer: string;
  variations: string;
  commonWrongAnswer: string;
  misconception: string;
  workedSolution: string;
  rubric: string;
  diagnostic: boolean;
}

interface BankTopic {
  code: string;
  grade: Grade;
  subject: string;
  name: string;
  strand: string;
  term: string;
  week: number;
  order: number;
  previousLearning: string;
  nextLearning: string;
  remediation: string;
  alternativeExplanation: string;
  prerequisiteRevision: string;
  likelyMisconception: string;
  assignment: {
    task: string;
    successCriteria: string;
    reflectionPrompt: string;
  };
  questions: BankQuestion[];
}

// The pack's worked solutions are mostly one template sentence ("Use the relevant rule/concept
// for X; ..."). That is not a worked solution, so it is not stored and never shown to a child.
const GENERIC_SOLUTION = /^use the relevant rule\/concept/i;

export const QUIZ_BANK_FILE = join(
  process.cwd(),
  'prisma',
  'data',
  'quiz-bank.json',
);

export async function loadQuizBank(
  prisma: PrismaClient,
  file = QUIZ_BANK_FILE,
): Promise<{ topics: number; questions: number }> {
  const bank = JSON.parse(readFileSync(file, 'utf8')) as {
    topics: BankTopic[];
  };

  let questions = 0;
  for (const t of bank.topics) {
    const data = {
      grade: t.grade,
      subject: t.subject,
      name: t.name,
      strand: t.strand,
      term: t.term,
      week: t.week,
      order: t.order,
      previousLearning: t.previousLearning,
      nextLearning: t.nextLearning,
      remediation: t.remediation,
      alternativeExplanation: t.alternativeExplanation,
      prerequisiteRevision: t.prerequisiteRevision,
      likelyMisconception: t.likelyMisconception,
      assignmentTask: t.assignment.task,
      assignmentCriteria: t.assignment.successCriteria,
      assignmentReflection: t.assignment.reflectionPrompt,
    };
    const topic = await prisma.quizTopic.upsert({
      where: { code: t.code },
      create: { code: t.code, ...data },
      update: data,
    });
    for (const q of t.questions) {
      const qData = {
        level: q.level,
        difficulty: q.difficulty,
        question: q.question,
        expectedAnswer: q.expectedAnswer,
        variations: q.variations,
        commonWrongAnswer: q.commonWrongAnswer,
        misconception: q.misconception,
        workedSolution: GENERIC_SOLUTION.test(q.workedSolution)
          ? ''
          : q.workedSolution,
        rubric: q.rubric,
        diagnostic: q.diagnostic,
      };
      await prisma.quizQuestion.upsert({
        where: { topicId_order: { topicId: topic.id, order: q.order } },
        create: { topicId: topic.id, order: q.order, ...qData },
        update: qData,
      });
      questions++;
    }
  }
  return { topics: bank.topics.length, questions };
}
