import { FileValidator } from '@nestjs/common';

/**
 * Accepts only real audio recordings (AAC/M4A, WAV, MP3, Ogg, WebM), judged by the file's
 * leading bytes rather than the type the client declares. Same approach as ImageFileValidator.
 */
export class AudioFileValidator extends FileValidator<Record<string, never>> {
  constructor() {
    super({});
  }

  isValid(file?: unknown): boolean {
    const buffer = (file as { buffer?: Buffer } | undefined)?.buffer;
    return !!buffer && isSupportedAudio(buffer);
  }

  buildErrorMessage(): string {
    return 'Validation failed (the recording must be an M4A, WAV, MP3, Ogg or WebM audio file)';
  }
}

export function isSupportedAudio(buffer: Buffer): boolean {
  if (buffer.length < 12) return false;
  const ascii = (from: number, to: number) =>
    buffer.subarray(from, to).toString('ascii');
  const isM4a = ascii(4, 8) === 'ftyp'; // MP4 / M4A container
  const isWav = ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WAVE';
  const isMp3 =
    ascii(0, 3) === 'ID3' ||
    (buffer[0] === 0xff && (buffer[1] & 0xe0) === 0xe0);
  const isOgg = ascii(0, 4) === 'OggS';
  const isWebm = buffer
    .subarray(0, 4)
    .equals(Buffer.from([0x1a, 0x45, 0xdf, 0xa3]));
  return isM4a || isWav || isMp3 || isOgg || isWebm;
}
