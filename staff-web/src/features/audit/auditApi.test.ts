import { afterEach, describe, expect, it, vi } from 'vitest'
import { auditApi } from './auditApi'

const period = { start_date: '2026-11-01', end_date: '2026-11-14', time_zone: 'America/Bogota' as const }

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => { resolve = done })
  return { promise, resolve }
}

function responseWithPendingJson(signal: AbortSignal, bodyStarted: () => void): Response {
  const response = new Response(null, { status: 200 })
  response.json = vi.fn(() => new Promise((_, reject) => {
    bodyStarted()
    signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')), { once: true })
  })) as Response['json']
  return response
}

describe('auditApi request lifetime', () => {
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('keeps caller cancellation active while consuming a JSON response body', async () => {
    const bodyStarted = deferred<void>()
    const external = new AbortController()
    let requestSignal: AbortSignal | undefined
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      requestSignal = init?.signal as AbortSignal | undefined
      return responseWithPendingJson(requestSignal!, () => bodyStarted.resolve())
    }))

    const pending = auditApi.events(period, {}, { limit: 25 }, external.signal)
    await bodyStarted.promise
    external.abort()

    await expect(pending).rejects.toMatchObject({ name: 'AbortError' })
    expect(requestSignal?.aborted).toBe(true)
  })

  it('keeps the request timeout active while consuming a JSON response body', async () => {
    vi.useFakeTimers()
    const bodyStarted = deferred<void>()
    let requestSignal: AbortSignal | undefined
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      requestSignal = init?.signal as AbortSignal | undefined
      return responseWithPendingJson(requestSignal!, () => bodyStarted.resolve())
    }))

    const pending = auditApi.events(period, {}, { limit: 25 })
    await bodyStarted.promise
    const rejection = expect(pending).rejects.toMatchObject({ code: 'request_timeout', operation: 'events' })
    await vi.advanceTimersByTimeAsync(20_000)

    await rejection
    expect(requestSignal?.aborted).toBe(true)
  })

  it('does not consume a response if the request was aborted before headers arrived', async () => {
    const external = new AbortController()
    const response = new Response('{}', { status: 200 })
    const pendingResponse = deferred<Response>()
    let requestSignal: AbortSignal | undefined
    vi.stubGlobal('fetch', vi.fn((_input: RequestInfo | URL, init?: RequestInit) => {
      requestSignal = init?.signal as AbortSignal | undefined
      return pendingResponse.promise
    }))
    const pending = auditApi.events(period, {}, { limit: 25 }, external.signal)
    external.abort()
    pendingResponse.resolve(response)

    await expect(pending).rejects.toMatchObject({ name: 'AbortError' })
    expect(requestSignal?.aborted).toBe(true)
  })
})
