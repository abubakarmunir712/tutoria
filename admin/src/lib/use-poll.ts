import { useCallback, useEffect, useRef, useState } from "react"

/**
 * Runs `load` now and then every `everyMs`, keeping the last good result on screen if a
 * refresh fails. `reload` fetches straight away (after a change, or for a "Refresh" button).
 */
export function usePoll<T>(load: () => Promise<T>, everyMs: number | null, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const loadRef = useRef(load)
  useEffect(() => {
    loadRef.current = load
  })

  const reload = useCallback(async () => {
    try {
      setData(await loadRef.current())
      setError(null)
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load")
    }
  }, [])

  useEffect(() => {
    void reload()
    if (!everyMs) return
    const id = setInterval(() => {
      if (!document.hidden) void reload()
    }, everyMs)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reload, everyMs, ...deps])

  return { data, error, loading: data === null && error === null, reload }
}
