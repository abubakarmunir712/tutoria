import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { JwtStrategy } from '../src/auth/strategies/jwt.strategy';
import { ChatModule } from '../src/chat/chat.module';

// GET /curriculum/topics: auth, query validation and the hand-off to the AI service (mocked).
const SECRET = 'test-secret';
const AI_URL = 'http://ai.test';
const TOPICS = {
  grade: 'B5',
  subject: 'Mathematics',
  strands: [{ name: 'Number', topics: [{ name: 'Fractions', lessons: 6 }] }],
};

describe('GET /curriculum/topics (e2e)', () => {
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
    token = moduleRef.get(JwtService).sign({ sub: 'user-1' });
  });

  beforeEach(() => {
    fetchSpy = jest
      .spyOn(global, 'fetch')
      .mockResolvedValue(new Response(JSON.stringify(TOPICS), { status: 200 }));
  });
  afterEach(() => fetchSpy.mockRestore());
  afterAll(() => app.close());

  const get = (query: string) =>
    request(app.getHttpServer())
      .get(`/curriculum/topics${query}`)
      .set('Authorization', `Bearer ${token}`);

  it('requires a login token', async () => {
    await request(app.getHttpServer())
      .get('/curriculum/topics?grade=B5&subject=Mathematics')
      .expect(401);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('rejects a missing or unknown grade, and a missing subject', async () => {
    await get('?subject=Mathematics').expect(400);
    await get('?grade=B1&subject=Mathematics').expect(400);
    await get('?grade=B5').expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('returns the AI service topics for the grade and subject', async () => {
    const res = await get(
      '?grade=B5&subject=Our%20World%20and%20Our%20People',
    ).expect(200);
    expect(res.body).toEqual(TOPICS);
    const [url] = fetchSpy.mock.calls[0] as [string];
    const params = new URL(url).searchParams;
    expect(url.startsWith(`${AI_URL}/topics?`)).toBe(true);
    expect(params.get('grade')).toBe('B5');
    expect(params.get('subject')).toBe('Our World and Our People');
  });

  it('is a 404 when the curriculum has no topics there', async () => {
    fetchSpy.mockResolvedValue(new Response('none', { status: 404 }));
    await get('?grade=B5&subject=Nonexistent').expect(404);
  });

  it('surfaces other AI service failures as a 500', async () => {
    fetchSpy.mockResolvedValue(new Response('boom', { status: 503 }));
    await get('?grade=B5&subject=Mathematics').expect(500);
  });
});
