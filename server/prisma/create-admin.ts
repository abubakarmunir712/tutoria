import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

// Creates (or promotes) an admin account for the dashboard:
//   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='...' npm run admin:create
// Optional: ADMIN_NAME, ADMIN_PHONE. An existing account with that email keeps its password
// unless ADMIN_PASSWORD is given.
const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

async function main() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  if (!email) throw new Error('Set ADMIN_EMAIL');
  const existing = await prisma.user.findUnique({ where: { email } });
  if (!existing && (!password || password.length < 8)) {
    throw new Error('Set ADMIN_PASSWORD (at least 8 characters)');
  }
  const passwordHash = password ? await bcrypt.hash(password, 12) : undefined;

  if (existing) {
    await prisma.user.update({
      where: { email },
      data: { isAdmin: true, ...(passwordHash && { passwordHash }) },
    });
    console.log(`${email} is now an admin.`);
    return;
  }
  await prisma.user.create({
    data: {
      email,
      fullName: process.env.ADMIN_NAME ?? 'Tutoria Admin',
      // The phone column is unique and required; staff never log in with it.
      phone: process.env.ADMIN_PHONE ?? `+000${Date.now()}`,
      passwordHash: passwordHash as string,
      role: 'PARENT',
      isAdmin: true,
    },
  });
  console.log(`Created admin ${email}.`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (err) => {
    console.error(err instanceof Error ? err.message : err);
    await prisma.$disconnect();
    process.exit(1);
  });
