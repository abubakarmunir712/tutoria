import { Award, Bot, Camera, Coins, Flame, GraduationCap, ListChecks, MessageCircle, Mic, Star, Target, TriangleAlert, type LucideIcon } from "lucide-react"

import { Card, Empty, ErrorNote, Stat } from "@/components/ui-bits"
import { ago, gradeLabel, KIND_LABEL, num, usd } from "@/lib/format"
import { getOverview } from "@/lib/api"
import { usePoll } from "@/lib/use-poll"

const POLL_MS = 10_000
const KIND_ICON: Record<string, LucideIcon> = { QUESTION: MessageCircle, PHOTO: Camera, VOICE: Mic }

export function OverviewPage() {
  const { data, error, loading, reload } = usePoll(getOverview, POLL_MS)

  if (!data) {
    return error ? <ErrorNote message={error} onRetry={reload} /> : <Empty>{loading ? "Loading…" : ""}</Empty>
  }
  const pct = data.limits.costTodayPercent
  const nearCap = pct !== null && pct >= data.limits.costAlertPercent

  return (
    <div className="space-y-4">
      {error && <ErrorNote message={`Showing the last numbers we got. ${error}`} onRetry={reload} />}
      {data.alerts.length > 0 && (
        <ul className="space-y-2" aria-label="Alerts">
          {data.alerts.map((a) => (
            <li
              key={a.id}
              role="alert"
              className={`rounded-3xl p-4 text-sm ${a.level === "critical" ? "bg-[#ffe0e0] text-[#8a1010]" : "bg-[#fff1cf] text-[#7a4b00]"}`}
            >
              <div className="flex items-center gap-2 font-extrabold">
                <TriangleAlert className="size-4" /> {a.title}
              </div>
              <div className="mt-0.5">{a.detail}</div>
            </li>
          ))}
        </ul>
      )}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Stat icon={Flame} accent="orange" label="Active learners today" value={num(data.active.today)} hint={`${num(data.active.last7Days)} this week · ${num(data.active.last30Days)} this month`} />
        <Stat icon={MessageCircle} accent="blue" label="Questions today" value={num(data.questions.today)} hint={`${num(data.questions.last7Days)} in the last 7 days`} />
        <Stat
          icon={Coins} accent="green" label="AI spend today (est.)"
          value={usd(data.cost.today)}
          tone={nearCap ? "warn" : "default"}
          hint={
            pct === null
              ? "No daily cap set"
              : `${pct.toFixed(0)}% of the ${usd(data.limits.dailyCostCapUsd)} daily cap`
          }
        />
        <Stat
          icon={Target} accent="purple" label="Cost per session (7 days)"
          value={usd(data.cost.perSession7Days)}
          hint="a session is one learner's day of use"
        />
        <Stat icon={GraduationCap} accent="pink" label="Learners" value={num(data.people.learners)} hint={`${num(data.people.parents)} parent accounts`} />
        <Stat icon={Bot} accent="blue" label="AI calls today" value={num(data.cost.callsToday)} />
        <Stat
          icon={TriangleAlert}
          accent="orange"
          label="Failed calls today"
          value={num(data.cost.errorsToday)}
          tone={data.cost.errorsToday > 0 ? "bad" : "default"}
        />
        <Stat icon={Star} accent="yellow" label="XP awarded, all time" value={num(data.xpAwarded)} />
        <Stat
          icon={ListChecks} accent="pink" label="Quizzes finished today"
          value={num(data.quizzes.today)}
          hint={`${num(data.quizzes.last7Days)} this week`}
        />
        <Stat
          icon={GraduationCap} accent="green" label="Average quiz score (7 days)"
          value={data.quizzes.averageScore7Days === null ? "–" : `${Math.round(data.quizzes.averageScore7Days * 100)}%`}
        />
        <Stat icon={Award} accent="purple" label="Topics mastered" value={num(data.quizzes.masteredUnits)} hint="across all learners" />
      </div>

      <h2 className="pt-2 text-2xl">Happening now</h2>
      {data.recent.length === 0 ? (
        <Card>
          <Empty>No activity yet. It will show up here as learners ask questions.</Empty>
        </Card>
      ) : (
        <ul className="grid gap-3 md:grid-cols-2">
          {data.recent.map((e, n) => (
            <li
              key={e.id}
              className={`flex items-center gap-4 rounded-full p-3 pr-6 ${["bg-[#d4f7ee]", "bg-[#dbefff]", "bg-[#ffe0ec]", "bg-[#fee9a6]", "bg-[#e9dcff]"][n % 5]}`}
            >
              <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-white text-xl">
                {(() => {
                  const Icon = KIND_ICON[e.kind] ?? MessageCircle
                  return <Icon className="size-6 text-[var(--ink)]" strokeWidth={2.2} />
                })()}
              </div>
              <div className="min-w-0 flex-1 text-sm leading-tight">
                <div className="truncate font-extrabold text-[var(--ink)]">
                  {e.learner} <span className="font-semibold text-[var(--ink)]/70">· {gradeLabel(e.grade)}</span>
                </div>
                <div className="truncate text-[var(--ink)]/70">
                  {KIND_LABEL[e.kind] ?? e.kind} · {e.subject}
                  {e.topic ? ` · ${e.topic}` : ""}
                </div>
              </div>
              <div className="shrink-0 text-right text-xs font-bold text-[var(--ink)]/70">
                <div className="inline-flex items-center gap-1 rounded-full bg-white px-2.5 py-0.5 text-[var(--ink)]"><Star className="size-3 fill-[#ffc21a] text-[#ffc21a]" /> +{e.xp} XP</div>
                <div className="mt-0.5">{ago(e.at)}</div>
              </div>
            </li>
          ))}
        </ul>
      )}
      <p className="text-xs text-muted-foreground">Updates every 10 seconds.</p>
    </div>
  )
}
