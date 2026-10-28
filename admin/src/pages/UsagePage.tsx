import { useState } from "react"

import { Bot, Coins, Target, TriangleAlert } from "lucide-react"

import { Bars, Card, Empty, ErrorNote, HBars, Stat } from "@/components/ui-bits"
import { KIND_LABEL, num, shortDay, usd } from "@/lib/format"
import { getUsage } from "@/lib/api"
import { usePoll } from "@/lib/use-poll"

const RANGES = [7, 14, 30, 90]

export function UsagePage() {
  const [days, setDays] = useState(14)
  const { data, error, loading, reload } = usePoll(() => getUsage(days), 30_000, [days])

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
            <Stat icon={Bot} accent="blue" label="AI calls" value={num(data.totals.calls)} />
            <Stat icon={Coins} accent="green" label="Estimated spend" value={usd(data.totals.cost)} />
            <Stat icon={Target} accent="purple" label="Cost per session" value={usd(data.totals.costPerSession)} hint={`${num(data.totals.sessions)} learner-days`} />
            <Stat icon={TriangleAlert} accent="orange" label="Failed calls" value={num(data.totals.errors)} tone={data.totals.errors ? "bad" : "default"} />
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <Card title="Spend per day (estimated)">
              <Bars
                items={data.daily.map((d) => ({ label: shortDay(d.day), value: d.cost }))}
                format={usd}
                color="green"
                every={Math.ceil(data.daily.length / 8)}
              />
            </Card>
            <Card title="AI calls per day">
              <Bars
                items={data.daily.map((d) => ({ label: shortDay(d.day), value: d.calls }))}
                color="pink"
                every={Math.ceil(data.daily.length / 8)}
              />
            </Card>
            <Card title="Busiest hours (UTC, which is Ghana time)">
              <Bars items={data.byHour.map((h) => ({ label: String(h.hour), value: h.questions }))} color="orange" every={3} />
            </Card>
            <Card title="Subjects">
              <HBars
                items={data.bySubject.map((s) => ({
                  label: s.subject,
                  value: s.questions,
                  display: `${num(s.questions)} questions`,
                  sub: `${s.learners} learner${s.learners === 1 ? "" : "s"}`,
                }))}
              />
            </Card>
          </div>

          <Card title="What the AI is used for">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-left text-xs text-muted-foreground">
                  <tr>
                    <th className="py-1 font-bold">Call</th>
                    <th className="py-1 text-right font-bold">Calls</th>
                    <th className="py-1 text-right font-bold">Est. cost</th>
                    <th className="py-1 text-right font-bold">Avg time</th>
                    <th className="py-1 text-right font-bold">Failed</th>
                  </tr>
                </thead>
                <tbody className="divide-y tabular-nums">
                  {data.byKind.map((k) => (
                    <tr key={k.kind}>
                      <td className="py-2">{KIND_LABEL[k.kind] ?? k.kind}</td>
                      <td className="py-2 text-right">{num(k.calls)}</td>
                      <td className="py-2 text-right">{usd(k.cost)}</td>
                      <td className="py-2 text-right">{(k.avgMs / 1000).toFixed(1)} s</td>
                      <td className="py-2 text-right">{k.errors}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {data.byKind.length === 0 && <Empty>No AI calls in this period.</Empty>}
            </div>
            <p className="mt-3 text-xs text-muted-foreground">
              Costs are estimates from message sizes and the prices set on the server; check your AI
              provider's invoice for exact figures.
            </p>
          </Card>
        </>
      )}
    </div>
  )
}
