import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { JwtStrategy } from '../src/auth/strategies/jwt.strategy';
import { ChatModule } from '../src/chat/chat.module';

// Voice endpoints: auth, upload validation, and the hand-off to the AI service (mocked).

const SECRET = 'test-secret';
const AI_URL = 'http://ai.test';
// Smallest believable WAV header + a few samples: validation reads magic bytes, not the type.
const WAV = Buffer.concat([
  Buffer.from('RIFF'),
  Buffer.from([36, 0, 0, 0]),
  Buffer.from('WAVEfmt '),
  Buffer.alloc(24),
]);

describe('voice endpoints (e2e)', () => {
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

  afterEach(() => fetchSpy?.mockRestore());
  afterAll(() => app.close());

  const auth = (path: string) =>
    request(app.getHttpServer())
      .post(path)
      .set('Authorization', `Bearer ${token}`);

  describe('POST /chat/transcribe', () => {
    it('requires a login token', async () => {
      fetchSpy = jest.spyOn(global, 'fetch');
      await request(app.getHttpServer())
        .post('/chat/transcribe')
        .attach('audio', WAV, { filename: 'q.wav', contentType: 'audio/wav' })
        .expect(401);
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('rejects a request with no recording', async () => {
      fetchSpy = jest.spyOn(global, 'fetch');
      await auth('/chat/transcribe').expect(400);
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('rejects a non-audio upload even if it claims to be audio', async () => {
      fetchSpy = jest.spyOn(global, 'fetch');
      await auth('/chat/transcribe')
        .attach('audio', Buffer.from('this is plain text, not audio'), {
          filename: 'q.m4a',
          contentType: 'audio/mp4',
        })
        .expect(400);
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('forwards a recording and returns the text', async () => {
      fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(
        new Response(JSON.stringify({ text: 'what is a noun' }), {
          status: 200,
        }),
      );
      const res = await auth('/chat/transcribe')
        .attach('audio', WAV, { filename: 'q.wav', contentType: 'audio/wav' })
        .expect(201);
      expect(res.body).toEqual({ text: 'what is a noun' });
      expect(fetchSpy).toHaveBeenCalledWith(
        `${AI_URL}/transcribe-audio`,
        expect.anything(),
      );
    });

    it('reports an AI service failure as a 500', async () => {
      fetchSpy = jest
        .spyOn(global, 'fetch')
        .mockResolvedValue(new Response('boom', { status: 502 }));
      await auth('/chat/transcribe')
        .attach('audio', WAV, { filename: 'q.wav', contentType: 'audio/wav' })
        .expect(500);
    });
  });

  describe('POST /chat/speak', () => {
    it('requires a login token', async () => {
      await request(app.getHttpServer())
        .post('/chat/speak')
        .send({ text: 'hello' })
        .expect(401);
    });

    it('rejects empty text', async () => {
      fetchSpy = jest.spyOn(global, 'fetch');
      await auth('/chat/speak').send({ text: '' }).expect(400);
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('returns the audio from the AI service with its type', async () => {
      fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(
        new Response(WAV, {
          status: 200,
          headers: { 'Content-Type': 'audio/wav' },
        }),
      );
      const res = await auth('/chat/speak')
        .send({ text: 'Well done!' })
        .expect(201);
      expect(res.headers['content-type']).toContain('audio/wav');
      expect(
        Buffer.from(res.body as Buffer)
          .subarray(0, 4)
          .toString(),
      ).toBe('RIFF');
    });
  });
});
