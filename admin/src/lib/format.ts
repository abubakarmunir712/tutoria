export const usd = (n: number) =>
  n === 0 ? "$0.00" : n < 0.01 ? `$${n.toFixed(4)}` : `$${n.toFixed(2)}`

export const num = (n: number) => n.toLocaleString("en-GB")

const GRADES: Record<string, string> = {
  B4: "Class 4",
  B5: "Class 5",
  B6: "Class 6",
  B7: "JHS 1",
  B8: "JHS 2",
  B9: "JHS 3",
  SHS1: "SHS 1",
  SHS2: "SHS 2",
  SHS3: "SHS 3",
}
export const gradeLabel = (g: string | null) => (g ? (GRADES[g] ?? g) : "No class")

export function ago(iso: string | null, now = Date.now()) {
  if (!iso) return "never"
  const s = Math.max(0, Math.round((now - new Date(iso).getTime()) / 1000))
  if (s < 60) return "just now"
  if (s < 3600) return `${Math.floor(s / 60)} min ago`
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`
  const d = Math.floor(s / 86400)
  return d === 1 ? "yesterday" : `${d} days ago`
}

/** "2026-10-24" -> "24 Oct" */
export function shortDay(day: string) {
  return new Date(`${day}T00:00:00Z`).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  })
}

export const KIND_LABEL: Record<string, string> = {
  QUESTION: "Question",
  PHOTO: "Homework photo",
  VOICE: "Spoken question",
  ASK: "Typed question",
  ASK_IMAGE: "Homework photo",
  TRANSCRIBE: "Speech to text",
  SPEAK: "Text to speech",
  QUIZ: "Quiz",
  CHECK: "Quick check",
  ASSIGNMENT: "Assignment",
  GRADE: "Marking",
}

export const MASTERY_LABEL: Record<string, string> = {
  EMERGING: "Emerging",
  DEVELOPING: "Developing",
  SECURE: "Secure",
  MASTERED: "Mastered",
  NEEDS_REVISION: "Needs revision",
}
