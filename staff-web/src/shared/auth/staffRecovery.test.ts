import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  parseRecoveryCodes,
  parseStaffSessionView,
  StaffAuthApiError,
  staffAuthApi,
  type StaffMfaChallengeView,
} from '../api/staffAuthApi'
import { StaffSessionCoordinator } from './staffSessionCoordinator'

const challenge: StaffMfaChallengeView = {
  status: 'mfa_required',
  enrollment_required: true,
  challenge_expires_at: '2026-11-15T12:05:00Z',
}

function jsonResponse(body: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

describe('administrator role in the session contract', () => {
  it('accepts an administrator session and still rejects customers', () => {
    const view = {
      user: { id: 1, email: 'admin@example.test', role: 'admin' },
      access_expires_at: '2026-11-15T12:10:00Z',
      renewable_expires_at: '2026-11-15T12:15:00Z',
      absolute_expires_at: '2026-11-15T16:00:00Z',
    }

    expect(parseStaffSessionView(view).user.role).toBe('admin')
    expect(() => parseStaffSessionView({ ...view, user: { ...view.user, role: 'user' } })).toThrow(StaffAuthApiError)
  })
})

describe('recovery and activation client calls', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })
  afterEach(() => vi.unstubAllGlobals())

  it('posts the recovery proof with the password and maps HTTP 202 to a challenge', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(challenge, 202))

    const result = await staffAuthApi.resetMfa('admin@example.test', 'pw-example', { recoveryCode: 'AAAA-BBBB-CCCC-DDDD' })

    expect(result).toEqual(challenge)
    const [url, init] = vi.mocked(fetch).mock.calls[0]!
    expect(String(url)).toBe('/api/v1/staff/auth/mfa/reset')
    expect(JSON.parse(String(init?.body))).toEqual({
      email: 'admin@example.test',
      password: 'pw-example',
      recovery_code: 'AAAA-BBBB-CCCC-DDDD',
    })
    expect(init?.credentials).toBe('include')
    expect(new Headers(init?.headers).get('X-Staff-Request')).toBe('1')
  })

  it('posts the current authenticator code for a replacement', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(challenge, 202))

    await staffAuthApi.resetMfa('admin@example.test', 'pw-example', { code: '123456' })

    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[0]![1]?.body))).toEqual({
      email: 'admin@example.test',
      password: 'pw-example',
      code: '123456',
    })
  })

  it('keeps the generic recovery failure code and exposes no server detail', async () => {
    vi.mocked(fetch).mockResolvedValue(
      jsonResponse({ code: 'mfa_recovery_invalid', detail: 'private reason' }, 401, { 'X-Correlation-ID': 'c-rec' }),
    )

    const error = await staffAuthApi
      .resetMfa('a@example.test', 'pw', { code: '000000' })
      .catch((value: unknown) => value)

    expect(error).toMatchObject({ status: 401, code: 'mfa_recovery_invalid', correlationId: 'c-rec', operation: 'mfa_reset' })
    expect(JSON.stringify(error)).not.toContain('private reason')
  })

  it('validates recovery codes strictly before they can be rendered', () => {
    expect(parseRecoveryCodes({ recovery_codes: ['AAAA-BBBB-CCCC-DDDD'] })).toEqual(['AAAA-BBBB-CCCC-DDDD'])
    for (const bad of [
      { recovery_codes: [] },
      { recovery_codes: ['not a code'] },
      { recovery_codes: ['aaaa-bbbb-cccc-dddd'] },
      { recovery_codes: 'AAAA-BBBB-CCCC-DDDD' },
      { codes: ['AAAA-BBBB-CCCC-DDDD'] },
    ]) {
      expect(() => parseRecoveryCodes(bad)).toThrow(StaffAuthApiError)
    }
  })

  it('treats activation as a no-content call and rejects a surprising body', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(new Response(null, { status: 204 }))
    await expect(staffAuthApi.activate('t'.repeat(43), 'pw-example', 'pw-example')).resolves.toBeUndefined()
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[0]![1]?.body))).toEqual({
      token: 't'.repeat(43),
      password: 'pw-example',
      password_confirmation: 'pw-example',
    })

    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse({ unexpected: true }, 200))
    await expect(staffAuthApi.activate('t'.repeat(43), 'a', 'a')).rejects.toMatchObject({ code: 'invalid_response' })
  })
})

describe('StaffSessionCoordinator.resetMfa', () => {
  const api = (resetMfa: ReturnType<typeof vi.fn>) => ({
    login: vi.fn(),
    session: vi.fn().mockRejectedValue(new StaffAuthApiError(401, 'session_invalid')),
    refresh: vi.fn(),
    logout: vi.fn(),
    resetMfa,
  })

  it('moves to the enrollment step on success without keeping the credentials in state', async () => {
    const resetMfa = vi.fn().mockResolvedValue(challenge)
    const coordinator = new StaffSessionCoordinator(api(resetMfa) as never, { channelFactory: null, storage: null })

    await coordinator.resetMfa('admin@example.test', 'pw-example', { recoveryCode: 'AAAA-BBBB-CCCC-DDDD' })

    expect(resetMfa).toHaveBeenCalledWith('admin@example.test', 'pw-example', { recoveryCode: 'AAAA-BBBB-CCCC-DDDD' })
    expect(coordinator.currentState).toEqual({ status: 'mfa_required', challenge, pending: false })
    expect(JSON.stringify(coordinator.currentState)).not.toContain('pw-example')
  })

  it('returns to anonymous with a safe message and diagnostic when verification fails', async () => {
    const resetMfa = vi.fn().mockRejectedValue(new StaffAuthApiError(401, 'mfa_recovery_invalid', 'c-1', null, 'mfa_reset'))
    const coordinator = new StaffSessionCoordinator(api(resetMfa) as never, { channelFactory: null, storage: null })

    await coordinator.resetMfa('admin@example.test', 'wrong', { code: '000000' })

    const state = coordinator.currentState
    expect(state.status).toBe('anonymous')
    if (state.status !== 'anonymous') throw new Error('unexpected state')
    expect(state.message).toContain('No se pudo verificar la recuperación')
    expect(state.diagnostic).toMatchObject({ code: 'mfa_recovery_invalid', operation: 'mfa_reset', correlationId: 'c-1' })
    expect(JSON.stringify(state)).not.toContain('wrong')
  })

  it('surfaces rate limiting as a recoverable error with the wait time', async () => {
    const resetMfa = vi.fn().mockRejectedValue(new StaffAuthApiError(429, 'mfa_rate_limited', null, 30, 'mfa_reset'))
    const coordinator = new StaffSessionCoordinator(api(resetMfa) as never, { channelFactory: null, storage: null })

    await coordinator.resetMfa('a@example.test', 'pw', { code: '000000' })

    expect(coordinator.currentState).toMatchObject({ status: 'recoverable_error', retryAfterSeconds: 30 })
  })
})
