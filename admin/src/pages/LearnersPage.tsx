import { useEffect, useState } from "react"

import { Flame, Star } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Card, Empty, ErrorNote } from "@/components/ui-bits"
import { ago, gradeLabel, num, usd } from "@/lib/format"
import { getLearners } from "@/lib/api"
import { usePoll } from "@/lib/use-poll"
import { LearnerPanel } from "./LearnerPanel"

const PAGE = 25

export function LearnersPage() {
  const [search, setSearch] = useState("")
  const [term, setTerm] = useState("")
  const [page, setPage] = useState(0)
  const [open, setOpen] = useState<string | null>(null)

  // Wait for a pause in typing before searching.
  useEffect(() => {
    const id = setTimeout(() => {
      setTerm(search.trim())
      setPage(0)
    }, 300)
    return () => clearTimeout(id)
  }, [search])

  const { data, error, loading, reload } = usePoll(
    () => getLearners(term, page * PAGE, PAGE),
    30_000,
    [term, page]
  )
  const pages = data ? Math.max(1, Math.ceil(data.total / PAGE)) : 1

  return (
    <div className="space-y-4">
      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search by learner, parent or email"
        className="h-11 w-full max-w-sm rounded-2xl border-2 bg-white px-4 text-sm outline-none focus-visible:border-[#0561e6]"
      />
      {error && <ErrorNote message={error} onRetry={reload} />}
      <Card>
        {!data ? (
          <Empty>{loading ? "Loading…" : ""}</Empty>
        ) : data.students.length === 0 ? (
          <Empty>{term ? "No learners match that search." : "No learners yet."}</Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-xs text-muted-foreground">
                <tr>
                  <th className="py-1 font-bold">Learner</th>
                  <th className="py-1 font-bold">Account</th>
                  <th className="py-1 text-right font-bold">Level</th>
                  <th className="py-1 text-right font-bold">XP</th>
                  <th className="py-1 text-right font-bold">Streak</th>
                  <th className="py-1 text-right font-bold">Questions</th>
                  <th className="py-1 text-right font-bold">Cost (30 d)</th>
                  <th className="py-1 text-right font-bold">Last active</th>
                </tr>
              </thead>
              <tbody className="divide-y tabular-nums">
                {data.students.map((s) => (
                  <tr key={s.id} className="cursor-pointer hover:bg-muted/50" onClick={() => setOpen(s.id)}>
                    <td className="py-2 pr-3">
                      <button
                        className="text-left font-extrabold text-[var(--ink)] hover:underline"
                        onClick={(e) => {
                          e.stopPropagation()
                          setOpen(s.id)
                        }}
                      >
                        {s.name}
                      </button>
                      <div className="text-xs text-muted-foreground">{gradeLabel(s.grade)}</div>
                    </td>
                    <td className="py-2 pr-3">
                      <div>{s.selfSignedUp ? "Student" : s.account}</div>
                      <div className="text-xs text-muted-foreground">{s.email}</div>
                    </td>
                    <td className="py-2 text-right"><span className="rounded-full bg-[#dbefff] px-2.5 py-0.5 font-extrabold text-[#0245b0]">Lv {s.level}</span></td>
                    <td className="py-2 text-right font-bold"><span className="inline-flex items-center justify-end gap-1">{num(s.xp)} <Star className="size-4 fill-[#ffc21a] text-[#ffc21a]" /></span></td>
                    <td className="py-2 text-right">{s.streak ? (<span className="inline-flex items-center justify-end gap-1">{s.streak} d <Flame className="size-4 fill-[#fc7b0a] text-[#fc7b0a]" /></span>) : "–"}</td>
                    <td className="py-2 text-right">{num(s.questions)}</td>
                    <td className="py-2 text-right">{usd(s.cost30Days)}</td>
                    <td className="py-2 text-right text-muted-foreground">{ago(s.lastActiveAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {open && <LearnerPanel id={open} onClose={() => setOpen(null)} />}
      {data && data.total > PAGE && (
        <div className="flex items-center justify-between text-sm text-muted-foreground">
          <span>
            {data.total} learners · page {page + 1} of {pages}
          </span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage(page - 1)}>
              Previous
            </Button>
            <Button variant="outline" size="sm" disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
