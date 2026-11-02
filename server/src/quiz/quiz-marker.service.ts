import { HttpException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Verdict } from '@prisma/client';
import { UsageService } from '../usage/usage.service';
import { isExactMatch, keywordVerdict } from './quiz-rules';

export interface Marked {
  verdict: Verdict;
  feedback: string;
  /** True when the AI service marked it (false: exact match, or the offline fallback). */
  ai: boolean;
}

const AI_TIMEOUT_MS = 25_000;
const VERDICTS: Record<string, Verdict> = {
  correct: 'CORRECT',
  partial: 'PARTIAL',
  incorrect: 'INCORRECT',
};

/** Marks written answers: an exact match first (free), then the AI service, then a keyword check
 *  if that is unavailable or the day's limits are reached, so a quiz never stalls on the AI. */
@Injectable()
export class QuizMarker {
  private readonly logger = new Logger(QuizMarker.name);
  private readonly baseUrl: string;

  constructor(
    config: ConfigService,
    private readonly usage: UsageService,
  ) {
    this.baseUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
  }

  async markAnswer(args: {
    studentId: string;
    grade: string;
    subject: string;
    question: string;
    expected: string;
    rubric: string;
    answer: string;
    firstTry: boolean;
  }): Promise<Marked> {
    if (isExactMatch(args.answer, args.expected)) {
      return { verdict: 'CORRECT', feedback: 'Correct. Well done!', ai: false };
    }
    const ai = await this.callAi(
      args.studentId,
      args.subject,
      {
        kind: 'question',
        grade: args.grade,
        subject: args.subject,
        question: args.question,
        expected_answer: args.expected,
        rubric: args.rubric,
        first_try: args.firstTry,
        answer: args.answer,
      },
      args.question.length + args.expected.length + args.answer.length,
    );
    if (ai) return { ...ai, ai: true };

    const verdict = keywordVerdict(args.answer, args.expected);
    return {
      verdict,
      feedback:
        verdict === 'CORRECT'
          ? 'That looks right. Well done!'
          : verdict === 'PARTIAL'
            ? 'You are on the right track. Check your answer once more.'
            : 'Not quite. Think about it again.',
      ai: false,
    };
  }

  /** An assignment is judged against its success criteria. Null when the AI is unavailable. */
  async markAssignment(args: {
    studentId: string;
    grade: string;
    subject: string;
    task: string;
    criteria: string;
    response: string;
    reflection: string;
  }): Promise<Marked | null> {
    const ai = await this.callAi(
      args.studentId,
      args.subject,
      {
        kind: 'assignment',
        grade: args.grade,
        subject: args.subject,
        task: args.task,
        success_criteria: args.criteria,
        reflection: args.reflection,
        answer: args.response,
      },
      args.task.length +
        args.criteria.length +
        args.response.length +
        args.reflection.length,
    );
    return ai ? { ...ai, ai: true } : null;
  }

  private async callAi(
    studentId: string,
    subject: string,
    body: Record<string, unknown>,
    inputChars: number,
  ): Promise<{ verdict: Verdict; feedback: string } | null> {
    try {
      await this.usage.checkAllowed(studentId, 'GRADE');
    } catch (e) {
      // Over today's cost cap: keep quizzes working with the offline check.
      if (e instanceof HttpException) return null;
      throw e;
    }
    const started = Date.now();
    let outputChars = 0;
    let ok = false;
    try {
      const res = await fetch(`${this.baseUrl}/grade`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(AI_TIMEOUT_MS),
      });
      if (!res.ok) throw new Error(`AI service answered ${res.status}`);
      const data = (await res.json()) as {
        verdict?: string;
        feedback?: string;
      };
      const verdict = VERDICTS[String(data.verdict).toLowerCase()];
      if (!verdict) throw new Error(`Unknown verdict ${String(data.verdict)}`);
      const feedback = (data.feedback ?? '').trim();
      outputChars = feedback.length + 40;
      ok = true;
      return { verdict, feedback };
    } catch (e) {
      this.logger.warn(`Marking failed, using the offline check: ${String(e)}`);
      return null;
    } finally {
      await this.usage.log({
        studentId,
        kind: 'GRADE',
        subject,
        inputChars,
        outputChars,
        ok,
        durationMs: Date.now() - started,
      });
    }
  }
}
