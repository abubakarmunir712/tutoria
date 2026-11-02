import { X } from "lucide-react"

import { Empty, ErrorNote } from "@/components/ui-bits"
import { getLearner } from "@/lib/api"
import { ago, gradeLabel, MASTERY_LABEL, num, usd } from "@/lib/format"
import { usePoll } from "@/lib/use-poll"

const percent = (n: number | null) => (n === null ? "–" : `${Math.round(n * 100)}%`)
const words = (code: string) => code.replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase())

/** One learner in depth: how they are doing, what they have mastered and their recent practice. */
export function LearnerPanel({ id, onClose }: { id: string; onClose: () => void }) {
  const { data, error, loading, reload } = usePoll(() => getLearner(id), 30_000, [id])

  return (
    <div className="fixed inset-0 z-40 flex justify-end bg-black/30" onClick={onClose}>
      <aside
        role="dialog"
        aria-label="Learner details"
        className="h-full w-full max-w-xl space-y-5 overflow-y-auto bg-white p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-2xl">{data?.name ?? "Learner"}</h2>
            {data && (
              <p className="text-sm text-muted-foreground">
                {gradeLabel(data.grade)} · {data.selfSignedUp ? "signed up on their own" : `${data.account} (parent)`} · {data.email}
              </p>
            )}
          </div>
          <button aria-label="Close" onClick={onClose} className="rounded-full p-2 hover:bg-muted">
            <X className="size-5" />
          </button>
        </div>

        {error && <ErrorNote message={error} onRetry={reload} />}
        {!data ? (
          <Empty>{loading ? "Loading…" : ""}</Empty>
        ) : (
          <>
            <dl className="grid grid-cols-3 gap-3 text-sm">
              {[
                ["Level", `Lv ${data.stats.level}`],
                ["XP", num(data.stats.xp)],
                ["Streak", `${data.stats.streak} d (best ${data.stats.bestStreak})`],
                ["Questions", num(data.stats.questions)],
                ["Quizzes", num(data.stats.quizzes)],
                ["Assignments", num(data.stats.assignments)],
                ["Mastered", num(data.stats.masteredTopics)],
                ["Saved chats", num(data.conversations)],
                ["AI cost (30 d)", usd(data.cost30Days)],
              ].map(([k, v]) => (
                <div key={k} className="rounded-2xl bg-[#f3f7ff] p-3">
                  <dt className="text-xs font-bold text-muted-foreground">{k}</dt>
                  <dd className="font-extrabold tabular-nums text-[var(--ink)]">{v}</dd>
                </div>
              ))}
            </dl>
            <p className="text-xs text-muted-foreground">
              Last active {ago(data.stats.lastActiveAt)}
              {data.subjects.length > 0 && ` · ${data.subjects.join(", ")}`}
              {data.hiddenFromLeaderboard && " · hidden from the leaderboard"}. Chat contents are private to the family and are not shown here.
            </p>

            <section>
              <h3 className="mb-2 text-lg">Topic mastery</h3>
              {data.mastery.length === 0 ? (
                <Empty>No quizzes taken yet.</Empty>
              ) : (
                <ul className="divide-y text-sm">
                  {data.mastery.map((m) => (
                    <li key={m.code} className="flex items-center justify-between gap-3 py-2">
                      <div className="min-w-0">
                        <div className="truncate font-bold text-[var(--ink)]">{m.topic}</div>
                        <div className="text-xs text-muted-foreground">
                          {m.subject} · {m.attempts} {m.attempts === 1 ? "attempt" : "attempts"} · best {percent(m.bestScore)}
                        </div>
                      </div>
                      <span className="shrink-0 rounded-full bg-[#dbefff] px-2.5 py-0.5 text-xs font-extrabold text-[#0245b0]">
                        {MASTERY_LABEL[m.state] ?? words(m.state)}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </section>

            <section>
              <h3 className="mb-2 text-lg">Recent quizzes</h3>
              {data.attempts.length === 0 ? (
                <Empty>Nothing finished yet.</Empty>
              ) : (
                <ul className="divide-y text-sm">
                  {data.attempts.map((a) => (
                    <li key={a.id} className="flex items-center justify-between gap-3 py-2">
                      <div className="min-w-0 truncate">
                        <span className="font-bold text-[var(--ink)]">{a.topic}</span>
                        <span className="text-muted-foreground"> · {a.mode === "CHECK" ? "Quick check" : "Quiz"} · {a.subject}</span>
                      </div>
                      <div className="shrink-0 text-right tabular-nums">
                        <span className="font-extrabold">{percent(a.score)}</span>
                        <span className="ml-2 text-xs text-muted-foreground">{ago(a.finishedAt)}</span>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </section>

            {data.assignments.length > 0 && (
              <section>
                <h3 className="mb-2 text-lg">Assignments</h3>
                <ul className="divide-y text-sm">
                  {data.assignments.map((a, i) => (
                    <li key={i} className="flex items-center justify-between gap-3 py-2">
                      <span className="truncate font-bold text-[var(--ink)]">{a.topic}</span>
                      <span className="shrink-0 text-xs text-muted-foreground">
                        {words(a.verdict.toLowerCase())} · {ago(a.at)}
                      </span>
                    </li>
                  ))}
                </ul>
              </section>
            )}

            {data.badges.length > 0 && (
              <section>
                <h3 className="mb-2 text-lg">Badges</h3>
                <div className="flex flex-wrap gap-2">
                  {data.badges.map((b) => (
                    <span key={b.code} className="rounded-full bg-[#fee9a6] px-3 py-1 text-xs font-bold text-[var(--ink)]">
                      {words(b.code)}
                    </span>
                  ))}
                </div>
              </section>
            )}
          </>
        )}
      </aside>
    </div>
  )
}
