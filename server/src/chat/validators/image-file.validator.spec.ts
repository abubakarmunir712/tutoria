import { ImageFileValidator, isSupportedImage } from './image-file.validator';

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
const WEBP = Buffer.concat([
  Buffer.from('RIFF', 'ascii'),
  Buffer.from([0x24, 0x00, 0x00, 0x00]),
  Buffer.from('WEBPVP8 ', 'ascii'),
]);

describe('isSupportedImage', () => {
  it.each([
    ['JPEG', JPEG],
    ['PNG', PNG],
    ['WebP', WEBP],
  ])('accepts %s', (_name, buffer) => {
    expect(isSupportedImage(buffer)).toBe(true);
  });

  it.each([
    ['text', Buffer.from('definitely not an image')],
    ['GIF', Buffer.from('GIF89a......')],
    ['PDF', Buffer.from('%PDF-1.7')],
    [
      'a RIFF file that is not WebP',
      Buffer.from('RIFF\x24\x00\x00\x00WAVEfmt ', 'binary'),
    ],
    ['a truncated PNG signature', PNG.subarray(0, 5)],
    ['empty', Buffer.alloc(0)],
  ])('rejects %s', (_name, buffer) => {
    expect(isSupportedImage(buffer)).toBe(false);
  });
});

describe('ImageFileValidator', () => {
  const validator = new ImageFileValidator();

  it('judges by content, ignoring the declared mimetype', () => {
    expect(validator.isValid({ mimetype: 'text/plain', buffer: JPEG })).toBe(
      true,
    );
    expect(
      validator.isValid({
        mimetype: 'image/jpeg',
        buffer: Buffer.from('hello'),
      }),
    ).toBe(false);
  });

  it('rejects a missing file or buffer', () => {
    expect(validator.isValid(undefined)).toBe(false);
    expect(validator.isValid({ mimetype: 'image/jpeg' })).toBe(false);
  });
});
