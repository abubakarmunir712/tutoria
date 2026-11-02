/** Something the admin should look at, worked out from today's cost and call numbers. */
export interface Alert {
  id: 'cap-reached' | 'near-cap' | 'spike' | 'failures';
  level: 'critical' | 'warning';
  title: string;
  detail: string;
}

export interface AlertInput {
  costToday: number;
  /** 0 when there is no cap */
  capUsd: number;
  /** percent of the cap that triggers the early warning */
  alertPercent: number;
  /** average daily spend over the days before today (0 when there is no history) */
  dailyAverageBefore: number;
  callsToday: number;
  errorsToday: number;
}

const SPIKE_FACTOR = 3;
/** Below this a "spike" is just a quiet day getting a few more calls. */
const SPIKE_MIN_USD = 0.5;
const FAILURE_MIN_CALLS = 10;
const FAILURE_SHARE = 0.25;

const usd = (n: number) => `$${n.toFixed(2)}`;

export function costAlerts(i: AlertInput): Alert[] {
  const alerts: Alert[] = [];
  if (i.capUsd > 0) {
    const pct = (i.costToday / i.capUsd) * 100;
    if (pct >= 100) {
      alerts.push({
        id: 'cap-reached',
        level: 'critical',
        title: 'Daily spend cap reached',
        detail: `Estimated spend is ${usd(i.costToday)} against a ${usd(i.capUsd)} cap. The tutor is paused for everyone until tomorrow (UTC); quizzes fall back to offline marking.`,
      });
    } else if (pct >= i.alertPercent) {
      alerts.push({
        id: 'near-cap',
        level: 'warning',
        title: `Spend is at ${Math.round(pct)}% of today's cap`,
        detail: `${usd(i.costToday)} of ${usd(i.capUsd)}. The tutor pauses at the cap; raise it on the Limits tab if this is expected.`,
      });
    }
  }
  if (
    i.dailyAverageBefore > 0 &&
    i.costToday >= SPIKE_MIN_USD &&
    i.costToday >= i.dailyAverageBefore * SPIKE_FACTOR
  ) {
    alerts.push({
      id: 'spike',
      level: 'warning',
      title: 'Spend is well above normal',
      detail: `${usd(i.costToday)} today, against about ${usd(i.dailyAverageBefore)} a day over the previous week.`,
    });
  }
  if (
    i.callsToday >= FAILURE_MIN_CALLS &&
    i.errorsToday / i.callsToday >= FAILURE_SHARE
  ) {
    alerts.push({
      id: 'failures',
      level: 'warning',
      title: 'Many AI calls are failing',
      detail: `${i.errorsToday} of ${i.callsToday} calls failed today. Check the AI service and provider keys.`,
    });
  }
  return alerts;
}
