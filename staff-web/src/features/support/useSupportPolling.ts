import { useEffect } from 'react'

export function useSupportPolling(refresh: (signal: AbortSignal) => Promise<void>) {
  useEffect(() => {
    const controller = new AbortController()
    let running = false
    async function tick() {
      if (running || document.hidden || controller.signal.aborted) return
      running = true
      try {
        await refresh(controller.signal)
      } finally {
        running = false
      }
    }
    const timer = window.setInterval(() => void tick(), 5000)
    document.addEventListener('visibilitychange', tick)
    return () => {
      controller.abort()
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', tick)
    }
  }, [refresh])
}
