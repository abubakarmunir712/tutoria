import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** How much of a long first question the history list keeps as the title. */
const TITLE_CHARS = 80;
/** How many earlier turns are given back to the tutor as context. */
const CONTEXT_TURNS = 10;

export interface Turn {
  role: 'user' | 'assistant';
  content: string;
}

export function titleFrom(text: string): string {
  const flat = text.replace(/\s+/g, ' ').trim();
  if (!flat) return 'Homework photo';
  return flat.length > TITLE_CHARS
    ? `${flat.slice(0, TITLE_CHARS - 1).trimEnd()}…`
    : flat;
}

/** The tutor chats a learner has had, so they can be listed, reopened and carried on. */
@Injectable()
export class ConversationsService {
  constructor(private readonly prisma: PrismaService) {}

  /** The learner's own conversation, or null when it isn't theirs (or doesn't exist). */
  private async owned(studentId: string, id: string) {
    return this.prisma.conversation.findFirst({ where: { id, studentId } });
  }

  /**
   * Save one exchange. Carries on [conversationId] when it is this learner's, otherwise starts
   * a new conversation titled by the question. Returns the conversation's id.
   */
  async saveExchange(
    studentId: string,
    input: {
      conversationId?: string;
      subject: string;
      grade?: string;
      topic?: string;
      question: string;
      hasImage?: boolean;
      answer: string;
      citations: unknown[];
    },
  ): Promise<string> {
    const now = new Date();
    const existing = input.conversationId
      ? await this.owned(studentId, input.conversationId)
      : null;
    const messages = {
      create: [
        {
          role: 'USER' as const,
          content: input.question,
          hasImage: input.hasImage ?? false,
          createdAt: now,
        },
        {
          role: 'ASSISTANT' as const,
          content: input.answer,
          citations: input.citations as Prisma.InputJsonValue,
          // A moment later, so the question always sorts before its answer.
          createdAt: new Date(now.getTime() + 1),
        },
      ],
    };
    if (existing) {
      await this.prisma.conversation.update({
        where: { id: existing.id },
        data: { lastMessageAt: now, messages },
      });
      return existing.id;
    }
    const created = await this.prisma.conversation.create({
      data: {
        studentId,
        subject: input.subject,
        grade: input.grade,
        topic: input.topic,
        title: titleFrom(input.question),
        lastMessageAt: now,
        messages,
      },
      select: { id: true },
    });
    return created.id;
  }

  /** The last few turns of a conversation, for when the app did not send its own. */
  async context(studentId: string, id: string): Promise<Turn[]> {
    if (!(await this.owned(studentId, id))) return [];
    const rows = await this.prisma.chatMessage.findMany({
      where: { conversationId: id },
      orderBy: { createdAt: 'desc' },
      take: CONTEXT_TURNS,
      select: { role: true, content: true, hasImage: true },
    });
    return rows.reverse().map((m) => ({
      role: m.role === 'USER' ? 'user' : 'assistant',
      content: m.content || (m.hasImage ? '[Sent a homework photo]' : ''),
    }));
  }

  /** Newest first. Optionally one subject. */
  async list(studentId: string, subject?: string, take = 50) {
    const rows = await this.prisma.conversation.findMany({
      where: { studentId, ...(subject ? { subject } : {}) },
      orderBy: { lastMessageAt: 'desc' },
      take: Math.min(Math.max(take, 1), 100),
      include: { _count: { select: { messages: true } } },
    });
    return rows.map((c) => ({
      id: c.id,
      title: c.title,
      subject: c.subject,
      grade: c.grade,
      topic: c.topic,
      messages: c._count.messages,
      lastMessageAt: c.lastMessageAt,
    }));
  }

  async get(studentId: string, id: string) {
    const c = await this.prisma.conversation.findFirst({
      where: { id, studentId },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!c) throw new NotFoundException('Conversation not found');
    return {
      id: c.id,
      title: c.title,
      subject: c.subject,
      grade: c.grade,
      topic: c.topic,
      lastMessageAt: c.lastMessageAt,
      messages: c.messages.map((m) => ({
        id: m.id,
        role: m.role === 'USER' ? 'user' : 'assistant',
        content: m.content,
        hasImage: m.hasImage,
        citations: m.citations ?? [],
        createdAt: m.createdAt,
      })),
    };
  }

  async remove(studentId: string, id: string) {
    const gone = await this.prisma.conversation.deleteMany({
      where: { id, studentId },
    });
    if (!gone.count) throw new NotFoundException('Conversation not found');
  }
}
