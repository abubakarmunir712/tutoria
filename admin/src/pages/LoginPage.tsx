import { useState, type FormEvent } from "react"

import { Button } from "@/components/ui/button"
import { signIn } from "@/lib/api"

export function LoginPage({ onSignedIn }: { onSignedIn: (name: string) => void }) {
  const [identifier, setIdentifier] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const admin = await signIn(identifier.trim(), password)
      onSignedIn(admin.fullName)
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not sign in")
    } finally {
      setBusy(false)
    }
  }

  const field =
    "mt-1 h-12 w-full rounded-2xl border-2 bg-white px-4 text-sm outline-none focus-visible:border-[#0561e6]"

  return (
    <div className="hero flex min-h-svh items-center justify-center p-4">
      <form onSubmit={submit} className="rise w-full max-w-sm space-y-4 rounded-[28px] bg-card p-7 shadow-[0_20px_50px_rgba(2,69,176,0.35)]">
        <div className="text-center">
          <img src="/img/mascot_hero.png" alt="" className="mx-auto h-28 object-contain" />
          <div className="mt-2 text-3xl font-black tracking-tight text-[var(--ink)]">Tutoria</div>
          <span className="mt-1 inline-block rounded-full bg-[#fee517] px-3 py-0.5 text-xs font-extrabold text-[#08185b]">Admin dashboard</span>
        </div>
        <label className="block text-sm font-bold text-[var(--ink)]">
          Email or phone
          <input
            className={field}
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            autoComplete="username"
            autoFocus
            required
          />
        </label>
        <label className="block text-sm font-bold text-[var(--ink)]">
          Password
          <input
            className={field}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>
        {error && (
          <p role="alert" className="text-sm text-destructive">
            {error}
          </p>
        )}
        <Button type="submit" size="lg" className="h-12 w-full rounded-2xl bg-[#fee517] text-base font-black text-[#08185b] hover:bg-[#ffc21a]" disabled={busy}>
          {busy ? "Signing in…" : "Sign in"}
        </Button>
      </form>
    </div>
  )
}
