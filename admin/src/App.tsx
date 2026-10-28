import { ChartColumn, Gauge, GraduationCap, House, LogOut } from "lucide-react"
import { useEffect, useState } from "react"

import { getOverview, hasSession, setSignedOutHandler, signOut } from "@/lib/api"
import { LearnersPage } from "@/pages/LearnersPage"
import { LimitsPage } from "@/pages/LimitsPage"
import { LoginPage } from "@/pages/LoginPage"
import { OverviewPage } from "@/pages/OverviewPage"
import { UsagePage } from "@/pages/UsagePage"

const TABS = [
  { id: "overview", label: "Overview", icon: House, title: "Welcome back" },
  { id: "usage", label: "Usage and cost", icon: ChartColumn, title: "Usage and cost" },
  { id: "learners", label: "Learners", icon: GraduationCap, title: "Learners" },
  { id: "limits", label: "Rate limits", icon: Gauge, title: "Rate limits" },
] as const
type Tab = (typeof TABS)[number]["id"]

const tabFromHash = (): Tab => {
  const id = window.location.hash.slice(1)
  return TABS.some((t) => t.id === id) ? (id as Tab) : "overview"
}

export function App() {
  // A saved session is checked with the server before the dashboard is shown.
  const [state, setState] = useState<"checking" | "out" | "in">(hasSession() ? "checking" : "out")
  const [tab, setTab] = useState<Tab>(tabFromHash)

  useEffect(() => {
    setSignedOutHandler(() => setState("out"))
    if (state === "checking") {
      getOverview().then(
        () => setState("in"),
        () => {
          signOut()
          setState("out")
        }
      )
    }
    const onHash = () => setTab(tabFromHash())
    window.addEventListener("hashchange", onHash)
    return () => window.removeEventListener("hashchange", onHash)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  if (state === "checking") {
    return <div className="flex min-h-svh items-center justify-center text-sm text-muted-foreground">Loading…</div>
  }
  if (state === "out") return <LoginPage onSignedIn={() => setState("in")} />

  const current = TABS.find((t) => t.id === tab)!
  return (
    <div className="flex min-h-svh flex-col bg-[#f6f9ff]">
      <div className="flex w-full flex-1 flex-col md:flex-row">
        <aside className="flex items-center gap-2 bg-white px-4 py-3 md:sticky md:top-0 md:h-svh md:w-24 md:flex-col md:px-0 md:py-8 md:shadow-[4px_0_24px_rgba(2,69,176,0.06)]">
          <img src="/img/logo_mark.png" alt="Tutoria" className="size-12 rounded-2xl" />
          <nav className="flex flex-1 items-center justify-center gap-2 md:flex-col md:justify-start md:gap-3 md:pt-10" aria-label="Sections">
            {TABS.map((t) => (
              <a
                key={t.id}
                href={`#${t.id}`}
                title={t.label}
                aria-label={t.label}
                aria-current={t.id === tab ? "page" : undefined}
                className={`flex size-12 items-center justify-center rounded-full text-xl transition-colors ${t.id === tab ? "bg-[#08185b] shadow-md" : "hover:bg-[#e2f1fe]"}`}
              >
                <t.icon className={`size-6 ${t.id === tab ? "text-white" : "text-[#2b3a67]"}`} strokeWidth={2.2} />
              </a>
            ))}
          </nav>
          <button
            title="Sign out"
            aria-label="Sign out"
            className="flex size-12 items-center justify-center rounded-full text-xl hover:bg-[#fdecec]"
            onClick={() => {
              signOut()
              setState("out")
            }}
          >
            <LogOut className="size-6 text-[#e5484d]" strokeWidth={2.2} />
          </button>
        </aside>
        <main className="min-w-0 flex-1 p-5 md:px-12 md:py-10">
          <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
            <h1 className="text-3xl font-black tracking-tight md:text-5xl">
              {current.title}
            </h1>
            <span className="rounded-full bg-[#fee517] px-4 py-1.5 text-sm font-extrabold text-[#08185b]">Tutoria Admin</span>
          </div>
          {tab === "overview" && <OverviewPage />}
          {tab === "usage" && <UsagePage />}
          {tab === "learners" && <LearnersPage />}
          {tab === "limits" && <LimitsPage />}
        </main>
      </div>
    </div>
  )
}

export default App
