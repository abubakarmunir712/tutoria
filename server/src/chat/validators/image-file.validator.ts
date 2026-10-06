import { FileValidator } from '@nestjs/common';

/**
 * Accepts only real JPEG, PNG or WebP images, judged by the file's leading bytes rather than
 * the type the client declares (a renamed text file says "image/jpeg" too).
 *
 * Deliberately dependency-free: Nest's built-in FileTypeValidator loads the ESM-only
 * `file-type` package with a dynamic import on every upload, which is fragile (it fails
 * closed under Jest's CommonJS sandbox) and far more than three formats need.
 */
export class ImageFileValidator extends FileValidator<Record<string, never>> {
  constructor() {
    super({});
  }

  isValid(file?: unknown): boolean {
    const buffer = (file as { buffer?: Buffer } | undefined)?.buffer;
    return !!buffer && isSupportedImage(buffer);
  }

  buildErrorMessage(): string {
    return 'Validation failed (the photo must be a JPEG, PNG or WebP image)';
  }
}

export function isSupportedImage(buffer: Buffer): boolean {
  const isJpeg = buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  const isPng =
    buffer.length >= 8 &&
    buffer
      .subarray(0, 8)
      .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  // WebP is a RIFF container: "RIFF" <size> "WEBP"
  const isWebp =
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP';
  return isJpeg || isPng || isWebp;
}
