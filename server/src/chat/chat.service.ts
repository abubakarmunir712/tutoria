import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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

export interface TopicsResponse {
  grade: string;
  subject: string;
  strands: Array<{ name: string; topics: Array<{ name: string; lessons: number }> }>;
}

@Injectable()
export class ChatService {
  private readonly baseUrl: string;

  constructor(config: ConfigService) {
    this.baseUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
  }

  async ask(dto: AskDto): Promise<AskResponse> {
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

  async askImage(dto: AskImageDto, file: Express.Multer.File): Promise<AskResponse> {
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

    const res = await fetch(`${this.baseUrl}/ask-image`, { method: 'POST', body: form });
    return this.handle(res);
  }

  async transcribe(file: Express.Multer.File): Promise<{ text: string }> {
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

  async speak(text: string): Promise<{ audio: Buffer; mimeType: string }> {
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
