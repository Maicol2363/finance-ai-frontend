import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { StaffAuthApiError, parseStaffSessionView, staffAuthApi } from './staffAuthApi'

const sessionView = {
  user: { id: 7, email: 'agent@example.test', role: 'support_agent' },
  access_expires_at: '2026-11-12T12:00:00Z',
  renewable_expires_at: '2026-11-12T12:30:00Z',
  absolute_expires_at: '2026-11-12T20:00:00Z',
}

function jsonResponse(body: unknown, status = 200, headers?: HeadersInit): Response {
  const responseHeaders = new Headers(headers)
  responseHeaders.set('Content-Type', 'application/json')
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  })
}

describe('staffAuthApi', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('sends only login credentials through the cookie-only C1 boundary', async () => {
    const fetchMock = vi.mocked(fetch).mockResolvedValue(jsonResponse(sessionView))

    await staffAuthApi.login('agent@example.test', 'correct horse battery staple')

    const [url, init] = fetchMock.mock.calls[0]
    const headers = new Headers(init?.headers)
    expect(url).toBe('/api/v1/staff/auth/login')
    expect(init?.method).toBe('POST')
    expect(init?.credentials).toBe('include')
    expect(init?.cache).toBe('no-store')
    expect(headers.get('X-Staff-Request')).toBe('1')
    expect(headers.get('Content-Type')).toBe('application/json')
    expect(headers.has('Authorization')).toBe(false)
    expect(JSON.parse(String(init?.body))).toEqual({
      email: 'agent@example.test',
      password: 'correct horse battery staple',
    })
  })

  it('uses the session path with credentials and the required request marker', async () => {
    const fetchMock = vi.mocked(fetch).mockResolvedValue(jsonResponse(sessionView))

    await staffAuthApi.session()

    const [url, init] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/v1/staff/auth/session')
    expect(init?.method).toBe('GET')
    expect(init?.credentials).toBe('include')
    expect(new Headers(init?.headers).get('X-Staff-Request')).toBe('1')
    expect(init?.body).toBeUndefined()
  })

  it('sends empty JSON objects for refresh and logout and accepts only logout 204', async () => {
    const fetchMock = vi
      .mocked(fetch)
      .mockResolvedValueOnce(jsonResponse(sessionView))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))

    await staffAuthApi.refresh()
    await staffAuthApi.logout()

    expect(fetchMock.mock.calls[0][0]).toBe('/api/v1/staff/auth/refresh')
    expect(fetchMock.mock.calls[1][0]).toBe('/api/v1/staff/auth/logout')
    expect(JSON.parse(String(fetchMock.mock.calls[0][1]?.body))).toEqual({})
    expect(JSON.parse(String(fetchMock.mock.calls[1][1]?.body))).toEqual({})
  })

  it('rejects unexpected roles and malformed required fields without trusting extra fields', () => {
    expect(parseStaffSessionView({ ...sessionView, extra: 'ignored' })).toMatchObject({
      user: { id: 7, role: 'support_agent' },
    })
    expect(() =>
      parseStaffSessionView({
        ...sessionView,
        user: { ...sessionView.user, role: 'admin' },
      }),
    ).toThrowError(StaffAuthApiError)
    expect(() => parseStaffSessionView({ ...sessionView, absolute_expires_at: 'tomorrow' }))
      .toThrowError(StaffAuthApiError)
  })

  it('maps server failures to safe codes and does not expose Problem detail', async () => {
    vi.mocked(fetch).mockResolvedValue(
      jsonResponse(
        { code: 'invalid_credentials', detail: 'private password and email were rejected' },
        401,
        { 'X-Correlation-ID': 'corr-safe', 'Retry-After': '4' },
      ),
    )

    const error = await staffAuthApi.login('agent@example.test', 'secret').catch((value: unknown) => value)

    expect(error).toBeInstanceOf(StaffAuthApiError)
    expect(error).toMatchObject({
      status: 401,
      code: 'invalid_credentials',
      correlationId: 'corr-safe',
      retryAfterSeconds: 4,
      operation: 'login',
    })
    expect((error as Error).message).not.toContain('private password')
  })

  it('turns transport failures into a generic network error', async () => {
    vi.mocked(fetch).mockRejectedValue(new TypeError('socket contains private request data'))

    await expect(staffAuthApi.session()).rejects.toMatchObject({ code: 'network_error', operation: 'session' })
    await expect(staffAuthApi.session()).rejects.not.toThrow('private request data')
  })

  it('aborts a request at the 15-second deadline', async () => {
    vi.useFakeTimers()
    vi.mocked(fetch).mockImplementation((_url, init) => {
      return new Promise((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')))
      })
    })

    const request = staffAuthApi.session()
    const rejection = expect(request).rejects.toMatchObject({ code: 'request_timeout' })
    await vi.advanceTimersByTimeAsync(15_000)

    await rejection
  })

  it('keeps the 15-second deadline active while reading a response body', async () => {
    vi.useFakeTimers()
    vi.mocked(fetch).mockImplementation((_url, init) => Promise.resolve(new Response(
      new ReadableStream<Uint8Array>({
        start(controller) {
          init?.signal?.addEventListener('abort', () => {
            controller.error(new DOMException('Aborted', 'AbortError'))
          })
        },
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )))

    const request = staffAuthApi.session()
    const rejection = expect(request).rejects.toMatchObject({ code: 'request_timeout' })
    await vi.advanceTimersByTimeAsync(15_000)

    await rejection
  })
})
