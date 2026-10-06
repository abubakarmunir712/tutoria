import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { JwtStrategy } from '../src/auth/strategies/jwt.strategy';
import { ChatModule } from '../src/chat/chat.module';

// Homework-photo endpoint: auth, upload validation, and the hand-off to the AI service.
// Runs without a database (the JWT check only reads the token) and with the AI service
// mocked, so it exercises the real controller, guard, interceptor and validation pipes.

const SECRET = 'test-secret';
const AI_URL = 'http://ai.test';
// A real (8x8) JPEG: the file-type check reads magic numbers, not just the declared type.
const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDrKKKKAP/Z',
  'base64',
);

describe('POST /chat/ask-image (e2e)', () => {
  let app: INestApplication<App>;
  let token: string;
  let fetchSpy: jest.SpyInstance;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          load: [() => ({ JWT_SECRET: SECRET, AI_SERVICE_URL: AI_URL })],
        }),
        PassportModule,
        JwtModule.register({ secret: SECRET }),
        ChatModule,
      ],
      providers: [JwtStrategy],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
    token = moduleRef.get(JwtService).sign({ sub: 'student-1' });
  });

  beforeEach(() => {
    fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ answer: 'ok', citations: [] }), {
        status: 200,
      }),
    );
  });

  afterEach(() => fetchSpy.mockRestore());
  afterAll(() => app.close());

  const post = () =>
    request(app.getHttpServer())
      .post('/chat/ask-image')
      .set('Authorization', `Bearer ${token}`);

  it('requires a login token', async () => {
    await request(app.getHttpServer())
      .post('/chat/ask-image')
      .attach('image', JPEG, { filename: 'h.jpg', contentType: 'image/jpeg' })
      .expect(401);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('rejects a request with no photo (400, not a crash)', async () => {
    await post().field('grade', 'B5').expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('rejects a non-image upload', async () => {
    await post()
      .attach('image', Buffer.from('hello'), {
        filename: 'a.txt',
        contentType: 'text/plain',
      })
      .expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('rejects a file that claims to be an image but is not', async () => {
    await post()
      .attach('image', Buffer.from('definitely not a jpeg'), {
        filename: 'fake.jpg',
        contentType: 'image/jpeg',
      })
      .expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('rejects photos over 10 MB', async () => {
    const big = Buffer.concat([JPEG, Buffer.alloc(10 * 1024 * 1024 + 1024)]);
    await post()
      .attach('image', big, { filename: 'big.jpg', contentType: 'image/jpeg' })
      .expect(413);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('passes a valid photo, grade, subject and history to the AI service', async () => {
    const history = JSON.stringify([
      { role: 'user', content: 'How do I add fractions?' },
    ]);
    const res = await post()
      .field('grade', 'B5')
      .field('subject', 'Mathematics')
      .field('history', history)
      .attach('image', JPEG, { filename: 'h.jpg', contentType: 'image/jpeg' })
      .expect(201);

    expect(res.body).toEqual({ answer: 'ok', citations: [] });
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0] as [string, { body: FormData }];
    expect(url).toBe(`${AI_URL}/ask-image`);
    expect(init.body.get('grade')).toBe('B5');
    expect(init.body.get('subject')).toBe('Mathematics');
    expect(init.body.get('history')).toBe(history);
    expect(init.body.get('image')).toBeInstanceOf(Blob);
  });

  it('surfaces an AI service failure as a 500 with its message', async () => {
    fetchSpy.mockResolvedValue(
      new Response('model unavailable', { status: 503 }),
    );
    const res = await post()
      .attach('image', JPEG, { filename: 'h.jpg', contentType: 'image/jpeg' })
      .expect(500);
    expect(JSON.stringify(res.body)).toContain('AI service error (503)');
  });
});
