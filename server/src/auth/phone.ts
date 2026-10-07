import { parsePhoneNumberFromString } from 'libphonenumber-js';

/**
 * A phone number in international form (+233241234567), or null if it isn't a valid number.
 * Numbers without a country code are read as Ghanaian, so "024 123 4567" and "+233241234567"
 * are the same account — otherwise a student who signed up one way couldn't log in the other.
 */
export function normalizePhone(raw: string): string | null {
  const parsed = parsePhoneNumberFromString(raw.trim(), 'GH');
  return parsed?.isValid() ? parsed.number : null;
}
