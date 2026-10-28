import type { LucideIcon } from "lucide-react"
import type { ReactNode } from "react"

import { cn } from "@/lib/utils"

export function Card({
  title,
  action,
  children,
  className,
}: {
  title?: string
  action?: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <section className={cn("rise rounded-[32px] bg-white p-6 text-card-foreground", className)}>
      {(title || action) && (
        <div className="mb-3 flex items-center justify-between gap-2">
          {title && <h2 className="text-xl">{title}</h2>}
          {action}
        </div>
      )}
      {children}
    </section>
  )
}

const ACCENTS = {
  blue: { tile: "bg-[#dbefff]", bar: "bg-[#0561e6]", text: "text-[#0561e6]" },
  pink: { tile: "bg-[#ffe0ec]", bar: "bg-[#ff4b7d]", text: "text-[#ff4b7d]" },
  green: { tile: "bg-[#d4f7ee]", bar: "bg-[#12b886]", text: "text-[#12b886]" },
  orange: { tile: "bg-[#ffe8d2]", bar: "bg-[#fc7b0a]", text: "text-[#fc7b0a]" },
  purple: { tile: "bg-[#e9dcff]", bar: "bg-[#8b4de8]", text: "text-[#8b4de8]" },
  yellow: { tile: "bg-[#fee9a6]", bar: "bg-[#ffc21a]", text: "text-[#e0a100]" },
} as const
export type Accent = keyof typeof ACCENTS

/** A big pastel tile: label, large number, and a white round badge with an icon. */
export function Stat({
  label,
  value,
  hint,
  tone = "default",
  icon: Icon,
  accent = "blue",
}: {
  label: string
  value: ReactNode
  hint?: ReactNode
  tone?: "default" | "warn" | "bad"
  icon?: LucideIcon
  accent?: Accent
}) {
  return (
    <div className={cn("rise flex min-h-36 flex-col justify-between rounded-[28px] p-5", ACCENTS[accent].tile)}>
      <div className="text-sm font-bold text-[var(--ink)]">{label}</div>
      <div className="flex items-end justify-between gap-2">
        <div className="min-w-0">
          <div
            className={cn(
              "text-4xl font-black leading-none tabular-nums text-[var(--ink)]",
              tone === "warn" && "text-orange-600",
              tone === "bad" && "text-destructive"
            )}
          >
            {value}
          </div>
          {hint && <div className="mt-2 text-xs font-semibold text-[var(--ink)]/65">{hint}</div>}
        </div>
        {Icon && (
          <div className={cn("flex size-12 shrink-0 items-center justify-center rounded-full bg-white", ACCENTS[accent].text)}>
            <Icon className="size-6" strokeWidth={2.2} />
          </div>
        )}
      </div>
    </div>
  )
}

/** Vertical bars with a label under each; values are scaled to the tallest. */
export function Bars({
  items,
  format = (n) => String(n),
  height = 120,
  every = 1,
  color = "blue",
}: {
  color?: Accent
  items: { label: string; value: number }[]
  format?: (n: number) => string
  height?: number
  /** show every Nth label (long ranges) */
  every?: number
}) {
  const max = Math.max(...items.map((i) => i.value), 0)
  return (
    <div className="flex items-end gap-1" style={{ height: height + 22 }}>
      {items.map((item, i) => (
        <div key={item.label + i} className="group relative flex min-w-0 flex-1 flex-col items-center justify-end">
          <div
            className={cn("w-full min-w-[3px] rounded-t-lg opacity-90 transition-opacity group-hover:opacity-100", ACCENTS[color].bar)}
            style={{ height: max ? Math.max(item.value ? 3 : 1, (item.value / max) * height) : 1 }}
            title={`${item.label}: ${format(item.value)}`}
          />
          <div className="mt-1 h-4 w-full truncate text-center text-[10px] text-muted-foreground">
            {i % every === 0 ? item.label : ""}
          </div>
        </div>
      ))}
    </div>
  )
}

const ROTATE: Accent[] = ["blue", "pink", "green", "orange", "purple", "yellow"]

/** Horizontal bars for ranked lists (subjects, call types). */
export function HBars({
  items,
}: {
  items: { label: string; value: number; display: string; sub?: string }[]
}) {
  const max = Math.max(...items.map((i) => i.value), 0)
  if (!items.length) return <Empty>Nothing yet.</Empty>
  return (
    <ul className="space-y-3">
      {items.map((i, n) => (
        <li key={i.label}>
          <div className="flex items-baseline justify-between gap-2 text-sm">
            <span className="truncate">{i.label}</span>
            <span className="tabular-nums text-muted-foreground">
              {i.display}
              {i.sub && <span className="ml-2 text-xs">{i.sub}</span>}
            </span>
          </div>
          <div className="mt-1 h-3 rounded-full bg-muted">
            <div
              className={cn("h-3 rounded-full", ACCENTS[ROTATE[n % ROTATE.length]].bar)}
              style={{ width: max ? `${Math.max(2, (i.value / max) * 100)}%` : 0 }}
            />
          </div>
        </li>
      ))}
    </ul>
  )
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="py-6 text-center text-sm text-muted-foreground">{children}</p>
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex items-center justify-between gap-3 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive">
      <span>{message}</span>
      {onRetry && (
        <button className="underline underline-offset-2" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  )
}
