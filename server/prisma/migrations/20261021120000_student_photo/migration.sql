-- Profile pictures are stored on disk; the row only records that one exists.
ALTER TABLE "Student"
    ADD COLUMN "photoMime" TEXT,
    ADD COLUMN "photoUpdatedAt" TIMESTAMP(3);
