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

    const res = await fetch(`${this.baseUrl}/ask-image`, { method: 'POST', body: form });
    return this.handle(res);
  }

  private async handle(res: Response): Promise<AskResponse> {
    if (!res.ok) {
      throw new InternalServerErrorException(
        `AI service error (${res.status}): ${await res.text()}`,
      );
    }
    return res.json() as Promise<AskResponse>;
  }
}
