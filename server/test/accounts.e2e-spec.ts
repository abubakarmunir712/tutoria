/* eslint-disable @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call -- supertest bodies are untyped (any) by nature */
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';

// Accounts end to end against a real Postgres: signup, parent -> children, subjects,
// ownership and roles, token refresh. Skipped unless TEST_DATABASE_URL points at a database
// that has had the migrations applied (never point it at real data — it creates users).
const DATABASE_URL = process.env.TEST_DATABASE_URL;
const suite = DATABASE_URL ? describe : describe.skip;

suite('Accounts (e2e, real database)', () => {
  let app: INestApplication<App>;
  let db: PrismaClient;
  const run = Date.now().toString(36);
  let phoneCounter = 0;

  // unique, valid Ghanaian mobile numbers per call
  const nextPhone = () =>
    `+23324${String(Date.now() % 10000).padStart(4, '0')}${String(phoneCounter++).padStart(3, '0')}`;
  const email = (name: string) => `${name}.${run}@example.com`;

  const subject = {} as Record<string, string>; // "Mathematics:UPPER_PRIMARY" -> id

  beforeAll(async () => {
    process.env.DATABASE_URL = DATABASE_URL;
    process.env.JWT_SECRET = 'e2e-secret';
    db = new PrismaClient({
      adapter: new PrismaPg({ connectionString: DATABASE_URL }),
    });
    for (const [name, phase] of [
      ['Mathematics', 'UPPER_PRIMARY'],
      ['English Language', 'UPPER_PRIMARY'],
      ['Our World and Our People', 'UPPER_PRIMARY'],
      ['Mathematics', 'JHS'],
      ['Social Studies', 'JHS'],
    ] as const) {
      const s = await db.subject.upsert({
        where: { name_phase: { name, phase } },
        create: { name, phase },
        update: {},
      });
      subject[`${name}:${phase}`] = s.id;
    }

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await db.user.deleteMany({ where: { email: { contains: `.${run}@` } } });
    await db.$disconnect();
    await app.close();
  });

  const http = () => request(app.getHttpServer());

  async function signup(
    name: string,
    role: 'PARENT' | 'STUDENT',
    extra: Record<string, unknown> = {},
  ) {
    const body = {
      fullName: name,
      email: email(name.toLowerCase().replace(/\W/g, '')),
      phone: nextPhone(),
      password: 'correct-horse-9',
      role,
      ...extra,
    };
    const res = await http().post('/auth/signup').send(body).expect(201);
    return {
      token: res.body.accessToken as string,
      refresh: res.body.refreshToken as string,
      body,
    };
  }
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });

  describe('signup and login', () => {
    it('creates a parent with no children yet', async () => {
      const { token, body } = await signup('Esi Parent', 'PARENT');
      const me = await http().get('/me').set(as(token)).expect(200);
      expect(me.body).toMatchObject({
        fullName: 'Esi Parent',
        role: 'PARENT',
        email: body.email,
        students: [],
      });
      expect(me.body.passwordHash).toBeUndefined();
    });

    it('gives a student their own learner profile', async () => {
      const { token } = await signup('Kwame Student', 'STUDENT');
      const me = await http().get('/me').set(as(token)).expect(200);
      expect(me.body.role).toBe('STUDENT');
      expect(me.body.students).toHaveLength(1);
      expect(me.body.students[0]).toMatchObject({
        name: 'Kwame Student',
        grade: null,
      });
    });

    it('rejects a duplicate email or phone with 409', async () => {
      const { body } = await signup('Dup One', 'PARENT');
      await http()
        .post('/auth/signup')
        .send({ ...body, phone: nextPhone() })
        .expect(409); // same email
      await http()
        .post('/auth/signup')
        .send({ ...body, email: email('other') })
        .expect(409); // same phone
    });

    it('rejects bad input with 400', async () => {
      const good = {
        fullName: 'Bad Input',
        email: email('bad'),
        phone: nextPhone(),
        password: 'correct-horse-9',
        role: 'PARENT',
      };
      await http()
        .post('/auth/signup')
        .send({ ...good, phone: '12345' })
        .expect(400);
      await http()
        .post('/auth/signup')
        .send({ ...good, password: 'short' })
        .expect(400);
      await http()
        .post('/auth/signup')
        .send({ ...good, role: 'ADMIN' })
        .expect(400);
      await http()
        .post('/auth/signup')
        .send({ ...good, email: 'not-an-email' })
        .expect(400);
      await http()
        .post('/auth/signup')
        .send({ ...good, fullName: '' })
        .expect(400);
    });

    it('treats local and international phone formats as the same number', async () => {
      const { body } = await signup('Phone Format', 'PARENT', {
        phone: '024 123 4567',
      }).catch(async () => {
        // number already used by an earlier run of this suite: use another local-format number
        return signup('Phone Format', 'PARENT', { phone: '0551234567' });
      });
      const intl = body.phone.startsWith('055')
        ? '+233551234567'
        : '+233241234567';
      await http()
        .post('/auth/login')
        .send({ identifier: intl, password: body.password })
        .expect(201);
      await http()
        .post('/auth/login')
        .send({ identifier: body.phone, password: body.password })
        .expect(201);
    });

    it('logs in by email regardless of case, and refuses a wrong password', async () => {
      const { body } = await signup('Login Case', 'PARENT');
      await http()
        .post('/auth/login')
        .send({ identifier: body.email.toUpperCase(), password: body.password })
        .expect(201);
      await http()
        .post('/auth/login')
        .send({ identifier: body.email, password: 'wrong-password' })
        .expect(401);
      await http()
        .post('/auth/login')
        .send({ identifier: 'nobody@example.com', password: body.password })
        .expect(401);
    });

    it('rotates refresh tokens: the old one stops working', async () => {
      const { refresh } = await signup('Refresh Me', 'PARENT');
      const next = await http()
        .post('/auth/refresh')
        .send({ refreshToken: refresh })
        .expect(201);
      expect(next.body.accessToken).toBeDefined();
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: refresh })
        .expect(401);
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: next.body.refreshToken })
        .expect(201);
    });

    it('requires a token for account routes', async () => {
      await http().get('/me').expect(401);
      await http().post('/me/students').send({}).expect(401);
    });
  });

  describe('a parent and their children', () => {
    let token: string;
    let child: { id: string };

    beforeAll(async () => {
      ({ token } = await signup('Ama Parent', 'PARENT'));
    });

    it('adds children with a class and school type', async () => {
      const res = await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: '  Ama  ', grade: 'B5', schoolType: 'PRIVATE' })
        .expect(201);
      child = res.body;
      expect(res.body).toMatchObject({
        name: 'Ama',
        grade: 'B5',
        schoolType: 'PRIVATE',
        enrollments: [],
      });
      await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: 'Kofi', grade: 'B8' })
        .expect(201);
      const me = await http().get('/me').set(as(token)).expect(200);
      expect(me.body.students.map((s: { name: string }) => s.name)).toEqual([
        'Ama',
        'Kofi',
      ]);
    });

    it('validates a new child', async () => {
      await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: '', grade: 'B5' })
        .expect(400);
      await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: 'X', grade: 'B1' })
        .expect(400);
      await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: 'X' })
        .expect(400);
    });

    it('lists only the subjects taught in a class phase', async () => {
      const primary = await http()
        .get('/me/subjects?grade=B5')
        .set(as(token))
        .expect(200);
      expect(
        primary.body.every(
          (s: { phase: string }) => s.phase === 'UPPER_PRIMARY',
        ),
      ).toBe(true);
      const jhs = await http()
        .get('/me/subjects?grade=B8')
        .set(as(token))
        .expect(200);
      expect(jhs.body.every((s: { phase: string }) => s.phase === 'JHS')).toBe(
        true,
      );
      await http().get('/me/subjects?grade=B1').set(as(token)).expect(400);
    });

    it("sets a child's subjects, replacing the previous choice", async () => {
      const maths = subject['Mathematics:UPPER_PRIMARY'];
      const english = subject['English Language:UPPER_PRIMARY'];
      let res = await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: [maths, english] })
        .expect(200);
      expect(
        res.body.enrollments
          .map((e: { subject: { name: string } }) => e.subject.name)
          .sort(),
      ).toEqual(['English Language', 'Mathematics']);
      res = await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: [maths] })
        .expect(200);
      expect(res.body.enrollments).toHaveLength(1);
      res = await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: [] })
        .expect(200);
      expect(res.body.enrollments).toHaveLength(0);
    });

    it('refuses subjects from another phase, unknown subjects and bad ids', async () => {
      const jhsMaths = subject['Mathematics:JHS'];
      await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: [jhsMaths] })
        .expect(400);
      await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: ['6f1b7a52-3a4c-4d58-9b2e-0c7a5f1d2e11'] })
        .expect(400);
      await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: ['nope'] })
        .expect(400);
    });

    it('drops subjects that do not exist in the new phase when the class changes', async () => {
      const maths = subject['Mathematics:UPPER_PRIMARY'];
      await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(token))
        .send({ subjectIds: [maths] })
        .expect(200);
      // Class 5 -> Class 6: same phase, subjects stay
      let res = await http()
        .patch(`/me/students/${child.id}`)
        .set(as(token))
        .send({ grade: 'B6' })
        .expect(200);
      expect(res.body.enrollments).toHaveLength(1);
      // Class 6 -> JHS 1: new phase, Upper Primary subjects go
      res = await http()
        .patch(`/me/students/${child.id}`)
        .set(as(token))
        .send({ grade: 'B7' })
        .expect(200);
      expect(res.body).toMatchObject({ grade: 'B7', enrollments: [] });
    });

    it('removes a child', async () => {
      const res = await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: 'Temp', grade: 'B4' })
        .expect(201);
      await http()
        .delete(`/me/students/${res.body.id}`)
        .set(as(token))
        .expect(204);
      const me = await http().get('/me').set(as(token)).expect(200);
      expect(
        me.body.students.find((s: { id: string }) => s.id === res.body.id),
      ).toBeUndefined();
    });

    it("keeps one family's children private from another", async () => {
      const { token: other } = await signup('Other Parent', 'PARENT');
      await http()
        .patch(`/me/students/${child.id}`)
        .set(as(other))
        .send({ name: 'Hijacked' })
        .expect(404);
      await http()
        .delete(`/me/students/${child.id}`)
        .set(as(other))
        .expect(404);
      await http()
        .put(`/me/students/${child.id}/subjects`)
        .set(as(other))
        .send({ subjectIds: [] })
        .expect(404);
      const me = await http().get('/me').set(as(other)).expect(200);
      expect(me.body.students).toEqual([]);
    });
  });

  describe('a student on their own', () => {
    it('cannot add or remove children, but manages their own profile', async () => {
      const { token } = await signup('Solo Student', 'STUDENT');
      await http()
        .post('/me/students')
        .set(as(token))
        .send({ name: 'Sibling', grade: 'B5' })
        .expect(403);

      const me = await http().get('/me').set(as(token)).expect(200);
      const own = me.body.students[0].id;
      await http().delete(`/me/students/${own}`).set(as(token)).expect(403);

      let res = await http()
        .patch(`/me/students/${own}`)
        .set(as(token))
        .send({ grade: 'B7', schoolType: 'PUBLIC' })
        .expect(200);
      expect(res.body).toMatchObject({ grade: 'B7', schoolType: 'PUBLIC' });
      res = await http()
        .put(`/me/students/${own}/subjects`)
        .set(as(token))
        .send({ subjectIds: [subject['Social Studies:JHS']] })
        .expect(200);
      expect(res.body.enrollments[0].subject.name).toBe('Social Studies');
    });

    it('cannot choose subjects before choosing a class', async () => {
      const { token } = await signup('No Class', 'STUDENT');
      const me = await http().get('/me').set(as(token)).expect(200);
      await http()
        .put(`/me/students/${me.body.students[0].id}/subjects`)
        .set(as(token))
        .send({ subjectIds: [subject['Mathematics:JHS']] })
        .expect(400);
    });
  });
});
