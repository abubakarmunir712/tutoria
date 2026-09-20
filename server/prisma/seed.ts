import 'dotenv/config';
import { PrismaClient, Phase } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

const subjects: { name: string; phase: Phase }[] = [
  { name: 'Mathematics', phase: Phase.UPPER_PRIMARY },
  { name: 'English Language', phase: Phase.UPPER_PRIMARY },
  { name: 'Science', phase: Phase.UPPER_PRIMARY },
  { name: 'Our World and Our People', phase: Phase.UPPER_PRIMARY },
  { name: 'Computing', phase: Phase.UPPER_PRIMARY },

  { name: 'Mathematics', phase: Phase.JHS },
  { name: 'English Language', phase: Phase.JHS },
  { name: 'Science', phase: Phase.JHS },
  { name: 'Social Studies', phase: Phase.JHS },
  { name: 'Computing', phase: Phase.JHS },

  { name: 'Mathematics', phase: Phase.SHS },
  { name: 'English Language', phase: Phase.SHS },
  { name: 'Science', phase: Phase.SHS },
  { name: 'Social Studies', phase: Phase.SHS },
  { name: 'Computing', phase: Phase.SHS },
];

async function main() {
  for (const subject of subjects) {
    await prisma.subject.upsert({
      where: { name_phase: { name: subject.name, phase: subject.phase } },
      create: subject,
      update: {},
    });
  }
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (err) => {
    console.error(err);
    await prisma.$disconnect();
    process.exit(1);
  });
