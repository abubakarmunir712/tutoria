/* eslint-disable @typescript-eslint/no-unsafe-member-access -- supertest bodies are untyped (any) by nature */
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';

// Profile pictures: stored on disk, owned per learner. Needs a real Postgres with the
// migrations applied (TEST_DATABASE_URL); skipped otherwise, like the accounts suite.
const DATABASE_URL = process.env.TEST_DATABASE_URL;
const suite = DATABASE_URL ? describe : describe.skip;

// A real (8x8) JPEG: the upload check reads magic numbers, not the declared type.
const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDrKKKKAP/Z',
  'base64',
);

suite('Student profile pictures (e2e, real database)', () => {
  let app: INestApplication<App>;
  let db: PrismaClient;
  let uploads: string;
  const run = Date.now().toString(36);
  let counter = 0;

  beforeAll(async () => {
    process.env.DATABASE_URL = DATABASE_URL;
    process.env.JWT_SECRET = 'e2e-secret';
    uploads = mkdtempSync(join(tmpdir(), 'tutoria-uploads-'));
    process.env.UPLOADS_DIR = uploads;
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

  afterAll(async () => {
    await db.user.deleteMany({
      where: { email: { contains: `.photo${run}@` } },
    });
    await db.$disconnect();
    await app.close();
    rmSync(uploads, { recursive: true, force: true });
  });

  const http = () => request(app.getHttpServer());
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });

  /** A parent with one child; returns the parent's token and the child's id. */
  async function parentWithChild() {
    const n = counter++;
    const signup = await http()
      .post('/auth/signup')
      .send({
        fullName: `Photo Parent ${n}`,
        email: `parent${n}.photo${run}@example.com`,
        phone: `+23324${String(Date.now() % 10000).padStart(4, '0')}${String(n).padStart(3, '0')}`,
        password: 'correct-horse-9',
        role: 'PARENT',
      })
      .expect(201);
    const token = signup.body.accessToken as string;
    const child = await http()
      .post('/me/students')
      .set(as(token))
      .send({ name: 'Ama', grade: 'B6', schoolType: 'PUBLIC' })
      .expect(201);
    return { token, id: child.body.id as string };
  }

  const upload = (token: string, id: string, bytes: Buffer = JPEG) =>
    http()
      .put(`/me/students/${id}/photo`)
      .set(as(token))
      .attach('photo', bytes, {
        filename: 'me.jpg',
        contentType: 'image/jpeg',
      });

  it('has no picture to begin with', async () => {
    const { token, id } = await parentWithChild();
    await http().get(`/me/students/${id}/photo`).set(as(token)).expect(404);
  });

  it('stores an uploaded picture on disk and serves the same bytes back', async () => {
    const { token, id } = await parentWithChild();
    const res = await upload(token, id).expect(200);
    expect(res.body.photoMime).toBe('image/jpeg');
    expect(res.body.photoUpdatedAt).toBeTruthy();
    expect(existsSync(join(uploads, 'students', id))).toBe(true);

    const got = await http()
      .get(`/me/students/${id}/photo`)
      .set(as(token))
      .buffer()
      .parse((r, cb) => {
        const chunks: Buffer[] = [];
        r.on('data', (c: Buffer) => chunks.push(c));
        r.on('end', () => cb(null, Buffer.concat(chunks)));
      })
      .expect(200);
    expect(got.headers['content-type']).toContain('image/jpeg');
    expect((got.body as Buffer).equals(JPEG)).toBe(true);

    // The profile in /me says a picture exists, so the app knows to fetch it.
    const me = await http().get('/me').set(as(token)).expect(200);
    expect(me.body.students[0].photoUpdatedAt).toBeTruthy();
  });

  it('rejects something that is not an image', async () => {
    const { token, id } = await parentWithChild();
    await upload(token, id, Buffer.from('definitely not a picture')).expect(
      400,
    );
    await http().put(`/me/students/${id}/photo`).set(as(token)).expect(400); // no file at all
  });

  it("keeps one family's pictures private", async () => {
    const owner = await parentWithChild();
    const other = await parentWithChild();
    await upload(owner.token, owner.id).expect(200);
    await http()
      .get(`/me/students/${owner.id}/photo`)
      .set(as(other.token))
      .expect(404);
    await upload(other.token, owner.id).expect(404);
    await http().get(`/me/students/${owner.id}/photo`).expect(401);
  });

  it('removes the picture, from disk and from the profile', async () => {
    const { token, id } = await parentWithChild();
    await upload(token, id).expect(200);
    const res = await http()
      .delete(`/me/students/${id}/photo`)
      .set(as(token))
      .expect(200);
    expect(res.body.photoUpdatedAt).toBeNull();
    expect(existsSync(join(uploads, 'students', id))).toBe(false);
    await http().get(`/me/students/${id}/photo`).set(as(token)).expect(404);
  });

  it('deletes the picture with the child', async () => {
    const { token, id } = await parentWithChild();
    await upload(token, id).expect(200);
    await http().delete(`/me/students/${id}`).set(as(token)).expect(204);
    expect(existsSync(join(uploads, 'students', id))).toBe(false);
  });
});
