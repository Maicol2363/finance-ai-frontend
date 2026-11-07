import { afterEach, describe, expect, it, vi } from 'vitest'
import { apiRequest, ApiClientError } from './apiClient'

describe('apiRequest', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('sends an ephemeral bearer value without browser credential storage', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ ready: true }), {
        headers: { 'Content-Type': 'application/json', 'X-Correlation-ID': 'server-id' },
      }),
    )
    vi.stubGlobal('fetch', fetchMock)
    vi.stubGlobal('crypto', { randomUUID: () => 'request-id' })

    await expect(apiRequest<{ ready: boolean }>('/api/v1/foundation', { accessCredential: 'short-lived' })).resolves.toEqual({ ready: true })

    const [, request] = fetchMock.mock.calls[0] as [URL, RequestInit]
    expect(request.credentials).toBe('omit')
    expect(new Headers(request.headers).get('Authorization')).toBe('Bearer short-lived')
    expect(new Headers(request.headers).get('X-Correlation-ID')).toBe('request-id')
  })

  it('returns only safe failure metadata', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('private detail', {
      status: 403,
      headers: { 'X-Correlation-ID': 'request-123' },
    })))

    await expect(apiRequest('/api/v1/private')).rejects.toMatchObject<ApiClientError>({
      name: 'ApiClientError',
      status: 403,
      correlationId: 'request-123',
      message: 'The API request could not be completed.',
    })
  })
})
