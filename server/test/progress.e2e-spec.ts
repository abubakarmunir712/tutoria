/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call -- supertest bodies are untyped (any) by nature */
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';
import { ProgressService } from '../src/progress/progress.service';

// Scores, streaks, badges, the parent dashboard data and the admin API, end to end against a
// real Postgres, with the AI service mocked. Skipped unless TEST_DATABASE_URL points at a
// migrated database (never real data: it creates users and changes rate-limit settings).
const DATABASE_URL = process.env.TEST_DATABASE_URL;
const suite = DATABASE_URL ? describe : describe.skip;

suite('Progress, gamification and admin (e2e, real database)', () => {
  let app: INestApplication<App>;
  let db: PrismaClient;
  let fetchSpy: jest.SpyInstance;
  const run = Date.now().toString(36);
  let phoneCounter = 0;
  const nextPhone = () =>
    `+23325${String(Date.now() % 10000).padStart(4, '0')}${String(phoneCounter++).padStart(3, '0')}`;

  beforeAll(async () => {
    process.env.DATABASE_URL = DATABASE_URL;
    process.env.JWT_SECRET = 'e2e-secret';
    db = new PrismaClient({
      adapter: new PrismaPg({ connectionString: DATABASE_URL }),
    });
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  beforeEach(() => {
    // The AI service. supertest talks to the app over plain http, so only the app's own
    // fetch() calls to the AI service are intercepted.
    fetchSpy = jest.spyOn(global, 'fetch').mockImplementation(() =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            answer: 'Add the tops, keep the bottom.',
            citations: [],
          }),
          { status: 200 },
        ),
      ),
    );
  });
  afterEach(() => fetchSpy.mockRestore());

  afterAll(async () => {
    await db.setting.deleteMany();
    await db.user.deleteMany({ where: { email: { contains: `.${run}@` } } });
    await db.$disconnect();
    await app.close();
  });

  const http = () => request(app.getHttpServer());
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });

  async function signup(name: string, role: 'PARENT' | 'STUDENT') {
    const res = await http()
      .post('/auth/signup')
      .send({
        fullName: name,
        email: `${name.toLowerCase().replace(/\W/g, '')}.${run}@example.com`,
        phone: nextPhone(),
        password: 'correct-horse-9',
        role,
      })
      .expect(201);
    return res.body.accessToken as string;
  }

  async function parentWithChild(name: string) {
    const token = await signup(`${name} Parent`, 'PARENT');
    const child = await http()
      .post('/me/students')
      .set(as(token))
      .send({ name: `${name} Child`, grade: 'B5', schoolType: 'PUBLIC' })
      .expect(201);
    return { token, childId: child.body.id as string };
  }

  const ask = (token: string, body: Record<string, unknown>) =>
    http()
      .post('/chat/ask')
      .set(as(token))
      .send({ question: 'What is 1/2 + 1/4?', ...body });

  describe('earning XP', () => {
    let token: string;
    let childId: string;

    beforeAll(async () => {
      ({ token, childId } = await parentWithChild('Ama'));
    });

    it('pays XP, starts a streak and unlocks the first badge on the first question', async () => {
      const res = await ask(token, {
        studentId: childId,
        subject: 'Mathematics',
        topic: 'Fractions',
      }).expect(201);
      expect(res.body.answer).toBe('Add the tops, keep the bottom.');
      expect(res.body.progress).toMatchObject({
        // 10 for the question + 10 for the first of the day
        xpGained: 20,
        xp: 20,
        level: 1,
        streak: 1,
        leveledUp: false,
      });
      expect(
        res.body.progress.newBadges.map((b: { code: string }) => b.code),
      ).toEqual(['first_question']);
    });

    it('pays only the base XP for later questions the same day', async () => {
      const res = await ask(token, {
        studentId: childId,
        subject: 'Mathematics',
      }).expect(201);
      expect(res.body.progress).toMatchObject({
        xpGained: 10,
        xp: 30,
        streak: 1,
      });
      expect(res.body.progress.newBadges).toEqual([]);
    });

    it('pays for a spoken question and unlocks the voice badge', async () => {
      const res = await ask(token, {
        studentId: childId,
        subject: 'Science',
        via: 'voice',
      }).expect(201);
      expect(res.body.progress.xpGained).toBe(10);
      expect(
        res.body.progress.newBadges.map((b: { code: string }) => b.code),
      ).toContain('voice_question');
    });

    it('does not add a progress block when the app does not say who is asking', async () => {
      const res = await ask(token, { subject: 'Mathematics' }).expect(201);
      expect(res.body.progress).toBeUndefined();
    });

    it('does not let a family ask on behalf of someone else’s child', async () => {
      const other = await parentWithChild('Kofi');
      await ask(other.token, { studentId: childId }).expect(404);
      await http()
        .get(`/me/students/${childId}/progress`)
        .set(as(other.token))
        .expect(404);
    });

    it('saves everything for the parent dashboard', async () => {
      const res = await http()
        .get(`/me/students/${childId}/progress`)
        .set(as(token))
        .expect(200);
      expect(res.body).toMatchObject({
        xp: 40,
        level: 1,
        streak: 1,
        bestStreak: 1,
        questions: 3,
        voices: 1,
        lastSubject: 'Science',
        questionsThisWeek: 3,
        xpThisWeek: 40,
        bySubject: { Mathematics: 2, Science: 1 },
      });
      expect(res.body.week).toHaveLength(7);
      expect(res.body.week[6]).toMatchObject({ count: 3, xp: 40 });
      expect(res.body.days).toHaveLength(1);
      expect(res.body.recentTopics[0]).toMatchObject({
        subject: 'Mathematics',
        topic: 'Fractions',
      });
      const earned = res.body.badges
        .filter((b: { earned: boolean }) => b.earned)
        .map((b: { code: string }) => b.code)
        .sort();
      expect(earned).toEqual(['first_question', 'voice_question']);
      expect(res.body.badges.length).toBeGreaterThan(earned.length);
    });

    it('lists every child with their score for the parent', async () => {
      const second = await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: 'Ama Second', grade: 'B4' })
        .expect(201);
      const res = await http().get('/me/progress').set(as(token)).expect(200);
      expect(res.body).toHaveLength(2);
      expect(res.body[0]).toMatchObject({ name: 'Ama Child', xp: 40 });
      expect(res.body[1]).toMatchObject({
        studentId: second.body.id,
        name: 'Ama Second',
        xp: 0,
        streak: 0,
      });
    });

    it('stops paying XP after the daily cap but still answers', async () => {
      const { token: t, childId: id } = await parentWithChild('Efua');
      let last: request.Response | undefined;
      for (let i = 0; i < 32; i++) {
        last = await ask(t, { studentId: id, subject: 'Mathematics' }).expect(
          201,
        );
      }
      expect(last?.body.answer).toBeDefined();
      expect(last?.body.progress.xpGained).toBe(0);
      const sum = await http()
        .get(`/me/students/${id}/progress`)
        .set(as(t))
        .expect(200);
      // 30 paid questions: 30 x 10, plus the first-of-day bonus of 10
      expect(sum.body.xp).toBe(310);
      expect(sum.body.questions).toBe(32);
    });
  });

  describe('streaks', () => {
    it('continues on the next day and resets after a missed day', async () => {
      const { childId } = await parentWithChild('Yaw');
      const service = app.get(ProgressService);
      const day = (d: string) => new Date(`${d}T10:00:00.000Z`);
      const a = { kind: 'QUESTION' as const, subject: 'Mathematics' };

      expect((await service.record(childId, a, day('2026-03-01'))).streak).toBe(
        1,
      );
      expect((await service.record(childId, a, day('2026-03-02'))).streak).toBe(
        2,
      );
      // the day it reaches 3 pays the 20 XP streak bonus: 10 + 10 + 20
      const third = await service.record(childId, a, day('2026-03-03'));
      expect(third).toMatchObject({ streak: 3, xpGained: 40 });
      expect(third.newBadges.map((b) => b.code)).toContain('streak_3');
      expect((await service.record(childId, a, day('2026-03-05'))).streak).toBe(
        1,
      );

      const summary = await service.summary(childId, day('2026-03-05'));
      expect(summary).toMatchObject({ streak: 1, bestStreak: 3 });
      // gone entirely once a whole day has been missed
      expect((await service.summary(childId, day('2026-03-08'))).streak).toBe(
        0,
      );
    });
  });

  describe('admin', () => {
    let adminToken: string;
    let parentToken: string;

    beforeAll(async () => {
      adminToken = await signup('Admin Person', 'PARENT');
      await db.user.updateMany({
        where: { email: { contains: `adminperson.${run}@` } },
        data: { isAdmin: true },
      });
      ({ token: parentToken } = await parentWithChild('Nana'));
    });

    it('cannot be claimed at signup', async () => {
      await http()
        .post('/auth/signup')
        .send({
          fullName: 'Sneaky',
          email: `sneaky.${run}@example.com`,
          phone: nextPhone(),
          password: 'correct-horse-9',
          role: 'ADMIN',
        })
        .expect(400);
      await http()
        .post('/auth/signup')
        .send({
          fullName: 'Sneaky',
          email: `sneaky2.${run}@example.com`,
          phone: nextPhone(),
          password: 'correct-horse-9',
          role: 'PARENT',
          isAdmin: true,
        })
        .expect(201);
      const row = await db.user.findUnique({
        where: { email: `sneaky2.${run}@example.com` },
      });
      expect(row?.isAdmin).toBe(false);
    });

    it('keeps everyone else out', async () => {
      await http().get('/admin/overview').expect(401);
      for (const path of [
        '/admin/me',
        '/admin/overview',
        '/admin/usage',
        '/admin/students',
        '/admin/settings',
      ]) {
        await http().get(path).set(as(parentToken)).expect(403);
      }
      await http()
        .put('/admin/settings')
        .set(as(parentToken))
        .send({ dailyQuestionLimit: 1 })
        .expect(403);
    });

    it('identifies the admin', async () => {
      const res = await http().get('/admin/me').set(as(adminToken)).expect(200);
      expect(res.body.fullName).toBe('Admin Person');
    });

    it('reports engagement, spend and recent activity', async () => {
      const res = await http()
        .get('/admin/overview')
        .set(as(adminToken))
        .expect(200);
      expect(res.body.people.learners).toBeGreaterThanOrEqual(4);
      expect(res.body.active.today).toBeGreaterThanOrEqual(2);
      expect(res.body.questions.today).toBeGreaterThanOrEqual(35);
      expect(res.body.cost.today).toBeGreaterThan(0);
      expect(res.body.cost.callsToday).toBeGreaterThanOrEqual(36);
      expect(res.body.cost.perSession7Days).toBeGreaterThan(0);
      expect(res.body.recent.length).toBeGreaterThan(0);
      expect(res.body.recent[0]).toMatchObject({ learner: expect.any(String) });
      expect(res.body.limits).toMatchObject({
        dailyQuestionLimit: 100,
        dailyCostCapUsd: 10,
      });
    });

    it('breaks usage down by day, call type, subject and hour', async () => {
      const res = await http()
        .get('/admin/usage?days=7')
        .set(as(adminToken))
        .expect(200);
      expect(res.body.daily).toHaveLength(7);
      expect(res.body.daily[6].calls).toBeGreaterThan(0);
      expect(res.body.byKind.map((k: { kind: string }) => k.kind)).toContain(
        'ASK',
      );
      expect(
        res.body.bySubject.map((s: { subject: string }) => s.subject),
      ).toContain('Mathematics');
      expect(res.body.byHour).toHaveLength(24);
      expect(res.body.totals.costPerSession).toBeGreaterThan(0);
      await http().get('/admin/usage?days=0').set(as(adminToken)).expect(400);
    });

    it('lists learners with their score and cost, and can search', async () => {
      const res = await http()
        .get('/admin/students?search=Ama%20Child')
        .set(as(adminToken))
        .expect(200);
      expect(res.body.total).toBe(1);
      expect(res.body.students[0]).toMatchObject({
        name: 'Ama Child',
        xp: 40,
        questions: 3,
        aiCalls30Days: 3,
      });
      expect(res.body.students[0].cost30Days).toBeGreaterThan(0);
    });

    it('enforces a per-learner daily question limit set by the admin', async () => {
      const { token, childId } = await parentWithChild('Limit');
      const saved = await http()
        .put('/admin/settings')
        .set(as(adminToken))
        .send({ dailyQuestionLimit: 2 })
        .expect(200);
      expect(saved.body.dailyQuestionLimit).toBe(2);

      await ask(token, { studentId: childId }).expect(201);
      await ask(token, { studentId: childId }).expect(201);
      const blocked = await ask(token, { studentId: childId }).expect(429);
      expect(blocked.body.message).toContain('Come back tomorrow');

      // other learners are not affected
      const other = await parentWithChild('Free');
      await ask(other.token, { studentId: other.childId }).expect(201);

      await http()
        .put('/admin/settings')
        .set(as(adminToken))
        .send({ dailyQuestionLimit: 0 })
        .expect(200);
      await ask(token, { studentId: childId }).expect(201);
    });

    it('pauses the tutor for everyone once the daily cost cap is reached', async () => {
      const { token, childId } = await parentWithChild('Cap');
      await http()
        .put('/admin/settings')
        .set(as(adminToken))
        .send({ dailyCostCapUsd: 0.0001 })
        .expect(200);
      const blocked = await ask(token, { studentId: childId }).expect(429);
      expect(blocked.body.message).toContain('short rest');
      const fetchCallsBefore = fetchSpy.mock.calls.length;
      await ask(token, { studentId: childId }).expect(429);
      expect(fetchSpy.mock.calls.length).toBe(fetchCallsBefore);

      await http()
        .put('/admin/settings')
        .set(as(adminToken))
        .send({ dailyCostCapUsd: 0 })
        .expect(200);
      await ask(token, { studentId: childId }).expect(201);
    });

    it('rejects nonsense limits', async () => {
      await http()
        .put('/admin/settings')
        .set(as(adminToken))
        .send({ dailyQuestionLimit: -5 })
        .expect(400);
      await http()
        .put('/admin/settings')
        .set(as(adminToken))
        .send({ dailyCostCapUsd: 'lots' })
        .expect(400);
    });

    it('logs failed AI calls without charging for them or paying XP', async () => {
      const { token, childId } = await parentWithChild('Broken');
      fetchSpy.mockImplementation(() =>
        Promise.resolve(new Response('model unavailable', { status: 503 })),
      );
      await ask(token, { studentId: childId }).expect(500);
      const log = await db.usageLog.findFirst({
        where: { studentId: childId },
        orderBy: { createdAt: 'desc' },
      });
      expect(log).toMatchObject({ ok: false, costUsd: 0, kind: 'ASK' });
      const sum = await http()
        .get(`/me/students/${childId}/progress`)
        .set(as(token))
        .expect(200);
      expect(sum.body.xp).toBe(0);
    });
  });
});
