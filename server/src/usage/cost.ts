import { UsageKind } from '@prisma/client';

// The AI service does not report real token usage, so cost is estimated from message sizes
// (about 4 characters per token) and per-model prices. Defaults match gpt-4.1-mini and the
// gpt-4o-mini speech models; override them with the env vars below when the model changes.
export interface Prices {
  /** USD per million input tokens */
  inPerM: number;
  /** USD per million output tokens */
  outPerM: number;
  /** USD per character spoken */
  ttsPerChar: number;
  /** flat USD per transcription */
  sttPerCall: number;
  /** extra flat USD for reading a photo */
  visionPerCall: number;
}

// The system prompt and retrieved curriculum records sent with every question.
export const PROMPT_OVERHEAD_CHARS = 6000;
const CHARS_PER_TOKEN = 4;

export function pricesFromEnv(
  get: (key: string) => string | undefined,
): Prices {
  const num = (key: string, fallback: number) => {
    const n = Number(get(key));
    return get(key) !== undefined && get(key) !== '' && Number.isFinite(n)
      ? n
      : fallback;
  };
  return {
    inPerM: num('PRICE_INPUT_PER_M_TOKENS', 0.4),
    outPerM: num('PRICE_OUTPUT_PER_M_TOKENS', 1.6),
    ttsPerChar: num('PRICE_TTS_PER_CHAR', 0.000015),
    sttPerCall: num('PRICE_STT_PER_CALL', 0.003),
    visionPerCall: num('PRICE_VISION_PER_CALL', 0.002),
  };
}

export function estimateCost(
  kind: UsageKind,
  inputChars: number,
  outputChars: number,
  p: Prices,
): number {
  const text = () =>
    (((inputChars + PROMPT_OVERHEAD_CHARS) / CHARS_PER_TOKEN) * p.inPerM +
      (outputChars / CHARS_PER_TOKEN) * p.outPerM) /
    1_000_000;
  switch (kind) {
    case 'ASK':
      return text();
    case 'ASK_IMAGE':
      return text() + p.visionPerCall;
    case 'TRANSCRIBE':
      return p.sttPerCall;
    case 'SPEAK':
      return inputChars * p.ttsPerChar;
  }
}
