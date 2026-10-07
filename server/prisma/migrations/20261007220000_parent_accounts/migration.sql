-- Split the login from the learner so a parent can own several children.
--   User    = a login (PARENT or STUDENT)
--   Student = a learner profile owned by a user (a parent's child, or a student's own)

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('PARENT', 'STUDENT');

-- CreateEnum
CREATE TYPE "SchoolType" AS ENUM ('PRIVATE', 'PUBLIC');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- Existing accounts become STUDENT users that keep the same id, so signed-in sessions (the
-- JWT subject and refresh tokens) stay valid. They had no name; use the start of their email
-- until they set one.
INSERT INTO "User" ("id", "fullName", "email", "phone", "passwordHash", "role", "createdAt", "updatedAt")
SELECT "id", split_part("email", '@', 1), "email", "phone", "passwordHash", 'STUDENT', "createdAt", "updatedAt"
FROM "Student";

-- Student becomes a learner profile owned by a user (its own user, for migrated accounts).
ALTER TABLE "Student"
    ADD COLUMN "userId" TEXT,
    ADD COLUMN "name" TEXT,
    ADD COLUMN "schoolType" "SchoolType";

UPDATE "Student" SET "userId" = "id", "name" = split_part("email", '@', 1);

ALTER TABLE "Student"
    ALTER COLUMN "userId" SET NOT NULL,
    ALTER COLUMN "name" SET NOT NULL;

DROP INDEX "Student_email_key";
DROP INDEX "Student_phone_key";

ALTER TABLE "Student"
    DROP COLUMN "email",
    DROP COLUMN "phone",
    DROP COLUMN "passwordHash";

-- CreateIndex
CREATE INDEX "Student_userId_idx" ON "Student"("userId");

-- AddForeignKey
ALTER TABLE "Student" ADD CONSTRAINT "Student_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Refresh tokens belong to the login, not the learner.
ALTER TABLE "RefreshToken" DROP CONSTRAINT "RefreshToken_studentId_fkey";
ALTER TABLE "RefreshToken" RENAME COLUMN "studentId" TO "userId";

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
