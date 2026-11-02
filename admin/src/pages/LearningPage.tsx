import { useState } from "react"

import { ClipboardCheck, GraduationCap, Percent, Target } from "lucide-react"

import { Bars, Card, Empty, ErrorNote, HBars, Stat } from "@/components/ui-bits"
import { MASTERY_LABEL, num, shortDay } from "@/lib/format"
import { getLearning } from "@/lib/api"
import { usePoll } from "@/lib/use-poll"

const RANGES = [7, 14, 30, 90]
const percent = (n: number) => `${Math.round(n * 100)}%`
const GRADE: Record<string, string> = {
  B4: "Class 4", B5: "Class 5", B6: "Class 6", B7: "JHS 1", B8: "JHS 2", B9: "JHS 3",
  SHS1: "SHS 1", SHS2: "SHS 2", SHS3: "SHS 3",
}

export function LearningPage() {
  const [days, setDays] = useState(30)
  const { data, error, loading, reload } = usePoll(() => getLearning(days), 30_000, [days])

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 text-sm">
        <span className="text-muted-foreground">Last</span>
        {RANGES.map((r) => (
          <button
            key={r}
            onClick={() => setDays(r)}
            className={`rounded-full border px-3.5 py-1 font-bold ${r === days ? "border-[#0561e6] bg-[#0561e6] text-white" : "bg-card hover:bg-muted"}`}
          >
            {r} days
          </button>
        ))}
      </div>

      {error && <ErrorNote message={error} onRetry={reload} />}
      {!data ? (
        <Empty>{loading ? "Loading…" : ""}</Empty>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <Stat icon={GraduationCap} accent="blue" label="Quizzes finished" value={num(data.totals.quizzes)} hint={`${num(data.totals.checks)} quick checks`} />
            <Stat icon={Percent} accent="green" label="Average score" value={data.totals.quizzes ? percent(data.totals.averageScore) : "–"} />
            <Stat icon={Target} accent="purple" label="Learners practising" value={num(data.totals.learners)} />
            <Stat icon={ClipboardCheck} accent="orange" label="Assignments handed in" value={num(data.totals.assignments)} />
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <Card title="Quizzes per day">
              <Bars
                items={data.daily.map((d) => ({ label: shortDay(d.day), value: d.quizzes }))}
                color="pink"
                every={Math.ceil(data.daily.length / 8)}
              />
            </Card>
            <Card title="Average score by subject">
              <HBars
                items={data.bySubject.map((s) => ({
                  label: s.subject,
                  value: s.avg,
                  display: percent(s.avg),
                  sub: `${num(s.quizzes)} quiz${s.quizzes === 1 ? "" : "zes"}`,
                }))}
              />
            </Card>
            <Card title="Hardest units (lowest average, 3+ quizzes)">
              <HBars
                items={data.hardest.map((u) => ({
                  label: u.name,
                  value: u.avg,
                  display: percent(u.avg),
                  sub: `${u.subject} · ${GRADE[u.grade] ?? u.grade} · ${u.quizzes} quizzes`,
                }))}
              />
            </Card>
            <Card title="Where learners stand (all time, units)">
              <HBars
                items={data.mastery.map((m) => ({
                  label: MASTERY_LABEL[m.state] ?? m.state,
                  value: m.units,
                  display: num(m.units),
                }))}
              />
            </Card>
          </div>
        </>
      )}
    </div>
  )
}
