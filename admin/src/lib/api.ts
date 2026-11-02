// Talks to the Tutoria server. Signs in with the same /auth/login the app uses; the account
// must be an admin (see `npm run admin:create` in server/) or every /admin call is refused.

const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? "http://localhost:3001"
const KEY = "tutoria-admin-session"

interface Session {
  accessToken: string
  refreshToken: string
}

export class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

function load(): Session | null {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? "null") as Session | null
  } catch {
    return null
  }
}

function save(session: Session | null) {
  try {
    if (session) localStorage.setItem(KEY, JSON.stringify(session))
    else localStorage.removeItem(KEY)
  } catch {
    // Private mode: the session just lasts until the page is closed.
  }
}

let session = load()
let onSignedOut: (() => void) | undefined

export function setSignedOutHandler(fn: () => void) {
  onSignedOut = fn
}

export const hasSession = () => session !== null

async function parse(res: Response) {
  const text = await res.text()
  const body: unknown = text ? JSON.parse(text) : null
  if (!res.ok) {
    const message = (body as { message?: string | string[] } | null)?.message
    throw new ApiError(
      res.status,
      (Array.isArray(message) ? message.join(", ") : message) ?? "Request failed"
    )
  }
  return body
}

async function refresh(): Promise<boolean> {
  if (!session) return false
  try {
    const res = await fetch(`${BASE}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: session.refreshToken }),
    })
    if (!res.ok) return false
    session = (await res.json()) as Session
    save(session)
    return true
  } catch {
    return false
  }
}

export async function request<T>(
  path: string,
  init: { method?: string; body?: unknown } = {}
): Promise<T> {
  const send = () =>
    fetch(`${BASE}${path}`, {
      method: init.method ?? "GET",
      headers: {
        "Content-Type": "application/json",
        ...(session ? { Authorization: `Bearer ${session.accessToken}` } : {}),
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    })
  let res = await send()
  // Access tokens last 15 minutes: renew once and retry.
  if (res.status === 401 && (await refresh())) res = await send()
  if (res.status === 401) {
    session = null
    save(null)
    onSignedOut?.()
  }
  return (await parse(res)) as T
}

export async function signIn(identifier: string, password: string) {
  const res = await fetch(`${BASE}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifier, password }),
  })
  session = (await parse(res)) as Session
  save(session)
  try {
    return await request<{ id: string; fullName: string; email: string }>("/admin/me")
  } catch (e) {
    signOut()
    if (e instanceof ApiError && e.status === 403) {
      throw new ApiError(403, "This account is not an admin.")
    }
    throw e
  }
}

export function signOut() {
  session = null
  save(null)
}

// --- Shapes returned by /admin/*

export interface Overview {
  generatedAt: string
  people: { parents: number; learners: number }
  active: { today: number; last7Days: number; last30Days: number }
  questions: { today: number; last7Days: number }
  xpAwarded: number
  cost: {
    today: number
    last7Days: number
    last30Days: number
    callsToday: number
    errorsToday: number
    perSession7Days: number
  }
  limits: {
    dailyQuestionLimit: number
    dailyCostCapUsd: number
    costTodayPercent: number | null
  }
  recent: {
    id: string
    kind: "QUESTION" | "PHOTO" | "VOICE"
    subject: string
    topic: string | null
    xp: number
    at: string
    learner: string
    grade: string | null
  }[]
}

export interface Usage {
  days: number
  daily: { day: string; calls: number; cost: number; errors: number; sessions: number }[]
  totals: { calls: number; cost: number; errors: number; sessions: number; costPerSession: number }
  byKind: { kind: string; calls: number; cost: number; avgMs: number; errors: number }[]
  bySubject: { subject: string; questions: number; learners: number }[]
  byHour: { hour: number; questions: number }[]
}

export interface Learning {
  days: number
  totals: { quizzes: number; checks: number; learners: number; averageScore: number; assignments: number }
  daily: { day: string; quizzes: number; avg: number }[]
  bySubject: { subject: string; quizzes: number; avg: number }[]
  hardest: { name: string; subject: string; grade: string; quizzes: number; avg: number }[]
  mastery: { state: string; units: number }[]
}

export interface LearnerRow {
  id: string
  name: string
  grade: string | null
  joinedAt: string
  account: string
  email: string
  selfSignedUp: boolean
  xp: number
  level: number
  streak: number
  questions: number
  lastActiveAt: string | null
  aiCalls30Days: number
  cost30Days: number
}

export interface Limits {
  dailyQuestionLimit: number
  dailyCostCapUsd: number
}

export const getOverview = () => request<Overview>("/admin/overview")
export const getUsage = (days: number) => request<Usage>(`/admin/usage?days=${days}`)
export const getLearning = (days: number) => request<Learning>(`/admin/learning?days=${days}`)
export const getLearners = (search: string, skip: number, take: number) =>
  request<{ total: number; students: LearnerRow[] }>(
    `/admin/students?take=${take}&skip=${skip}${search ? `&search=${encodeURIComponent(search)}` : ""}`
  )
export const getLimits = () => request<Limits>("/admin/settings")
export const saveLimits = (limits: Limits) =>
  request<Limits>("/admin/settings", { method: "PUT", body: limits })
