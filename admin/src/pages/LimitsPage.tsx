import { useState, type FormEvent } from "react"

import { Button } from "@/components/ui/button"
import { Card, Empty, ErrorNote } from "@/components/ui-bits"
import { getLimits, getOverview, saveLimits } from "@/lib/api"
import { usd } from "@/lib/format"
import { usePoll } from "@/lib/use-poll"

export function LimitsPage() {
  const limits = usePoll(getLimits, null)
  const today = usePoll(getOverview, 15_000)
  // What has been typed; until then the form shows the saved limits.
  const [draft, setDraft] = useState<{ questions?: string; cap?: string }>({})
  const questions = draft.questions ?? String(limits.data?.dailyQuestionLimit ?? "")
  const cap = draft.cap ?? String(limits.data?.dailyCostCapUsd ?? "")
  const setQuestions = (questions: string) => setDraft((d) => ({ ...d, questions }))
  const setCap = (cap: string) => setDraft((d) => ({ ...d, cap }))
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setSaving(true)
    setSaved(false)
    setProblem(null)
    try {
      const next = await saveLimits({
        dailyQuestionLimit: Math.round(Number(questions)),
        dailyCostCapUsd: Number(cap),
      })
      setDraft({
        questions: String(next.dailyQuestionLimit),
        cap: String(next.dailyCostCapUsd),
      })
      setSaved(true)
      void today.reload()
    } catch (err) {
      setProblem(err instanceof Error ? err.message : "Could not save")
    } finally {
      setSaving(false)
    }
  }

  if (!limits.data) {
    return limits.error ? (
      <ErrorNote message={limits.error} onRetry={limits.reload} />
    ) : (
      <Empty>Loading…</Empty>
    )
  }

  const pct = today.data?.limits.costTodayPercent
  const field =
    "mt-1 h-11 w-40 rounded-2xl border-2 bg-white px-4 text-sm tabular-nums outline-none focus-visible:border-[#0561e6]"

  return (
    <div className="max-w-xl space-y-4">
      <Card title="Rate limits">
        <form onSubmit={submit} className="space-y-4">
          <label className="block text-sm">
            Questions per learner, per day
            <input
              className={field}
              type="number"
              min={0}
              step={1}
              value={questions}
              onChange={(e) => setQuestions(e.target.value)}
              required
            />
            <span className="mt-1 block text-xs text-muted-foreground">
              Typed questions and homework photos. The learner sees a friendly "come back tomorrow"
              message. 0 turns this limit off.
            </span>
          </label>
          <label className="block text-sm">
            AI spend cap per day, for everyone (USD)
            <input
              className={field}
              type="number"
              min={0}
              step="0.5"
              value={cap}
              onChange={(e) => setCap(e.target.value)}
              required
            />
            <span className="mt-1 block text-xs text-muted-foreground">
              Once today's estimated spend reaches this, the tutor pauses until tomorrow (UTC). This
              protects against a surprise bill. 0 turns the cap off.
            </span>
          </label>
          {problem && (
            <p role="alert" className="text-sm text-destructive">
              {problem}
            </p>
          )}
          <div className="flex items-center gap-3">
            <Button type="submit" disabled={saving}>
              {saving ? "Saving…" : "Save limits"}
            </Button>
            {saved && <span className="text-sm text-green-600">Saved. Applies straight away.</span>}
          </div>
        </form>
      </Card>

      <Card title="Today so far">
        {today.data ? (
          <>
            <div className="text-sm">
              Estimated spend <span className="font-semibold tabular-nums">{usd(today.data.cost.today)}</span>
              {pct !== null && pct !== undefined && (
                <span className="text-muted-foreground"> · {pct.toFixed(0)}% of the cap</span>
              )}
            </div>
            {pct !== null && pct !== undefined && (
              <div className="mt-2 h-3 rounded-full bg-muted">
                <div
                  className={`h-3 rounded-full ${pct >= 100 ? "bg-destructive" : pct >= 80 ? "bg-amber-500" : "bg-[#0561e6]"}`}
                  style={{ width: `${Math.max(2, pct)}%` }}
                />
              </div>
            )}
            {pct !== null && pct !== undefined && pct >= 100 && (
              <p className="mt-2 text-sm text-destructive">The cap is reached: the tutor is paused for everyone.</p>
            )}
          </>
        ) : (
          <Empty>Loading…</Empty>
        )}
      </Card>
    </div>
  )
}
