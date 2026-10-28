import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UsageKind } from '@prisma/client';
import {
  RecordedProgress,
  ProgressService,
} from '../progress/progress.service';
import { UsageService } from '../usage/usage.service';
import { AskDto } from './dto/ask.dto';
import { AskImageDto } from './dto/ask-image.dto';

export interface AskResponse {
  answer: string;
  citations: Array<{
    indicator_code: string;
    strand: string;
    substrand: string;
    images: string[];
  }>;
}

/** An answer, plus what it earned the learner when the app said who was asking. */
export type TrackedAskResponse = AskResponse & { progress?: RecordedProgress };

export interface TopicsResponse {
  grade: string;
  subject: string;
  strands: Array<{
    name: string;
    topics: Array<{ name: string; lessons: number }>;
  }>;
}

@Injectable()
export class ChatService {
  private readonly baseUrl: string;

  constructor(
    config: ConfigService,
    private readonly progress: ProgressService,
    private readonly usage: UsageService,
  ) {
    this.baseUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
  }

  /**
   * Run one AI call with the bookkeeping around it: the learner must be the caller's own, the
   * daily limits must allow it, and the call is logged with its estimated cost either way.
   */
  private async tracked<T>(
    userId: string,
    studentId: string | undefined,
    kind: UsageKind,
    subject: string | undefined,
    inputChars: number,
    outputChars: (result: T) => number,
    run: () => Promise<T>,
  ): Promise<{ result: T; studentId: string | null }> {
    const owned = studentId
      ? await this.progress.requireOwned(userId, studentId)
      : null;
    await this.usage.checkAllowed(owned, kind);
    const started = Date.now();
    const entry = { studentId: owned, kind, subject, inputChars };
    try {
      const result = await run();
      await this.usage.log({
        ...entry,
        outputChars: outputChars(result),
        ok: true,
        durationMs: Date.now() - started,
      });
      return { result, studentId: owned };
    } catch (e) {
      await this.usage.log({
        ...entry,
        outputChars: 0,
        ok: false,
        durationMs: Date.now() - started,
      });
      throw e;
    }
  }

  async ask(userId: string, dto: AskDto): Promise<TrackedAskResponse> {
    const inputChars =
      dto.question.length +
      (dto.history ?? []).reduce((n, t) => n + t.content.length, 0);
    const { result, studentId } = await this.tracked(
      userId,
      dto.studentId,
      'ASK',
      dto.subject,
      inputChars,
      (r) => r.answer.length,
      () => this.askAi(dto),
    );
    if (!studentId) return result;
    return {
      ...result,
      progress: await this.progress.record(studentId, {
        kind: dto.via === 'voice' ? 'VOICE' : 'QUESTION',
        subject: dto.subject ?? 'General',
        topic: dto.topic,
      }),
    };
  }

  private async askAi(dto: AskDto): Promise<AskResponse> {
    const res = await fetch(`${this.baseUrl}/ask`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        question: dto.question,
        grade: dto.grade,
        subject: dto.subject,
        top_k: dto.topK ?? 3,
        history: dto.history ?? [],
      }),
    });
    return this.handle(res);
  }

  async askImage(
    userId: string,
    dto: AskImageDto,
    file: Express.Multer.File,
  ): Promise<TrackedAskResponse> {
    const { result, studentId } = await this.tracked(
      userId,
      dto.studentId,
      'ASK_IMAGE',
      dto.subject,
      (dto.history ?? '').length + 300,
      (r) => r.answer.length,
      () => this.askImageAi(dto, file),
    );
    if (!studentId) return result;
    return {
      ...result,
      progress: await this.progress.record(studentId, {
        kind: 'PHOTO',
        subject: dto.subject ?? 'General',
        topic: dto.topic,
      }),
    };
  }

  private async askImageAi(
    dto: AskImageDto,
    file: Express.Multer.File,
  ): Promise<AskResponse> {
    const form = new FormData();
    form.append(
      'image',
      new Blob([new Uint8Array(file.buffer)], { type: file.mimetype }),
      file.originalname,
    );
    if (dto.grade) form.append('grade', dto.grade);
    if (dto.subject) form.append('subject', dto.subject);
    form.append('top_k', String(dto.topK ?? 3));
    if (dto.history) form.append('history', dto.history);

    const res = await fetch(`${this.baseUrl}/ask-image`, {
      method: 'POST',
      body: form,
    });
    return this.handle(res);
  }

  async transcribe(
    userId: string,
    studentId: string | undefined,
    file: Express.Multer.File,
  ): Promise<{ text: string }> {
    const { result } = await this.tracked(
      userId,
      studentId,
      'TRANSCRIBE',
      undefined,
      0,
      () => 0,
      () => this.transcribeAi(file),
    );
    return result;
  }

  private async transcribeAi(
    file: Express.Multer.File,
  ): Promise<{ text: string }> {
    const form = new FormData();
    form.append(
      'audio',
      new Blob([new Uint8Array(file.buffer)], { type: file.mimetype }),
      file.originalname,
    );
    const res = await fetch(`${this.baseUrl}/transcribe-audio`, {
      method: 'POST',
      body: form,
    });
    if (!res.ok) await this.fail(res);
    return res.json() as Promise<{ text: string }>;
  }

  async speak(
    userId: string,
    studentId: string | undefined,
    text: string,
  ): Promise<{ audio: Buffer; mimeType: string }> {
    const { result } = await this.tracked(
      userId,
      studentId,
      'SPEAK',
      undefined,
      text.length,
      () => 0,
      () => this.speakAi(text),
    );
    return result;
  }

  private async speakAi(
    text: string,
  ): Promise<{ audio: Buffer; mimeType: string }> {
    const res = await fetch(`${this.baseUrl}/speak`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
    });
    if (!res.ok) await this.fail(res);
    return {
      audio: Buffer.from(await res.arrayBuffer()),
      mimeType: res.headers.get('content-type') ?? 'audio/wav',
    };
  }

  /** Strands and topics for a grade and subject, or null if the curriculum has none. */
  async topics(grade: string, subject: string): Promise<TopicsResponse | null> {
    const params = new URLSearchParams({ grade, subject });
    const res = await fetch(`${this.baseUrl}/topics?${params.toString()}`);
    if (res.status === 404) return null;
    if (!res.ok) {
      throw new InternalServerErrorException(
        `AI service error (${res.status}): ${await res.text()}`,
      );
    }
    return res.json() as Promise<TopicsResponse>;
  }

  private async handle(res: Response): Promise<AskResponse> {
    if (!res.ok) await this.fail(res);
    return res.json() as Promise<AskResponse>;
  }

  private async fail(res: Response): Promise<never> {
    throw new InternalServerErrorException(
      `AI service error (${res.status}): ${await res.text()}`,
    );
  }
}
