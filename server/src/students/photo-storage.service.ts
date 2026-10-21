import { Injectable, Logger } from '@nestjs/common';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

/**
 * Profile pictures on local disk, one file per learner: `<UPLOADS_DIR>/students/<id>`.
 * Ids are UUIDs checked by the controller, so a name can never escape the folder. In Docker
 * the folder is a volume, so pictures survive redeploys.
 */
@Injectable()
export class PhotoStorage {
  private readonly log = new Logger(PhotoStorage.name);

  private get dir() {
    return join(process.env.UPLOADS_DIR ?? './uploads', 'students');
  }

  async save(studentId: string, bytes: Buffer) {
    await mkdir(this.dir, { recursive: true });
    await writeFile(join(this.dir, studentId), bytes);
  }

  /** The picture's bytes, or null when the file is missing. */
  async read(studentId: string): Promise<Buffer | null> {
    try {
      return await readFile(join(this.dir, studentId));
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code === 'ENOENT') return null;
      throw e;
    }
  }

  async remove(studentId: string) {
    try {
      await rm(join(this.dir, studentId), { force: true });
    } catch (e) {
      // The row is the source of truth; a stuck file must not block deleting a child.
      this.log.warn(`Could not delete picture of ${studentId}: ${String(e)}`);
    }
  }
}
