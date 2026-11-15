import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  AdminApiError,
  adminApi,
  parseAdminAccount,
  parseAdminCase,
  parseStaffInvitation,
  safeAdminDiagnostic,
  safeAdminMessage,
} from './adminApi'

const TOKEN = 'T'.repeat(43)

export const account = {
  id: 7,
  email: 'customer@example.com',
  role: 'user',
  status: 'active',
  registered_at: '2026-01-02T03:04:05Z',
  account_type: 'login_account',
  suspension: null,
}

const adminCase = {
  ticket: {
    id: 3,
    subject: 'No puedo entrar',
    category: 'account',
    description: 'Detalle',
    status: 'escalated',
    created_at: '2026-11-12T12:00:00Z',
    assigned_staff_user_id: 2,
    resolution_summary: null,
  },
  customer: { id: 9, email: 'customer@example.com', is_active: true },
  messages: [{ id: 1, author_user_id: 9, body: 'Hola', created_at: '2026-11-12T12:05:00Z' }],
  history: [
    {
      id: 1,
      actor_user_id: 2,
      event_type: 'ticket_escalated',
      previous_status: 'in_progress',
      new_status: 'escalated',
      previous_assignee_user_id: null,
      new_assignee_user_id: null,
      created_at: '2026-11-12T12:10:00Z',
      internal_reason: 'Necesita un administrador',
    },
  ],
  escalation_reason: 'Necesita un administrador',
  owner_admin_id: null,
  owned_by_me: false,
  originating_agent: { user_id: 2, can_receive_return: true },
}

function jsonResponse(body: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

describe('admin API parsers', () => {
  it('accepts the documented account projection and nothing broader', () => {
    expect(parseAdminAccount(account)).toEqual(account)
    expect(parseAdminAccount({ ...account, password_hash: 'ignored' })).not.toHaveProperty('password_hash')
  })

  it.each([
    { ...account, id: 0 },
    { ...account, id: 1.5 },
    { ...account, status: 'banned' },
    { ...account, registered_at: 'yesterday' },
    { ...account, account_type: 'financial_account' },
    { ...account, email: 42 },
    null,
    [],
  ])('rejects a malformed account %#', (bad) => {
    expect(() => parseAdminAccount(bad)).toThrow(AdminApiError)
  })

  it('validates the one-time activation token shape', () => {
    const invitation = {
      invitation_id: 4,
      email: 'new@example.com',
      role: 'support_agent',
      expires_at: '2026-11-17T12:00:00Z',
      activation_token: TOKEN,
    }
    expect(parseStaffInvitation(invitation).activation_token).toBe(TOKEN)
    expect(() => parseStaffInvitation({ ...invitation, activation_token: 'short' })).toThrow(AdminApiError)
    expect(() => parseStaffInvitation({ ...invitation, role: 'admin' })).toThrow(AdminApiError)
  })

  it('parses a case including staff-only reasons and rejects bad ownership flags', () => {
    expect(parseAdminCase(adminCase).escalation_reason).toBe('Necesita un administrador')
    expect(() => parseAdminCase({ ...adminCase, owned_by_me: 'yes' })).toThrow(AdminApiError)
    expect(() => parseAdminCase({ ...adminCase, messages: 'none' })).toThrow(AdminApiError)
  })
})

describe('admin API transport', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })
  afterEach(() => vi.unstubAllGlobals())

  it('sends cookie credentials and the staff boundary header, never an Authorization header', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(account))

    await adminApi.lookupByEmail('Customer@Example.com')

    const [url, init] = vi.mocked(fetch).mock.calls[0]!
    expect(String(url)).toBe('/api/v1/staff/admin/accounts/lookup?email=Customer%40Example.com')
    expect(init?.credentials).toBe('include')
    expect(init?.cache).toBe('no-store')
    const headers = new Headers(init?.headers)
    expect(headers.get('X-Staff-Request')).toBe('1')
    expect(headers.has('Authorization')).toBe(false)
  })

  it('posts explicit confirmation with every state change', async () => {
    const staff = { ...account, role: 'support_agent', assignable_roles: ['security_auditor'] }
    vi.mocked(fetch)
      .mockResolvedValueOnce(jsonResponse({ ...account, status: 'suspended' }))
      .mockResolvedValueOnce(jsonResponse(account))
      .mockResolvedValueOnce(jsonResponse(staff))

    await adminApi.suspend(7, 'fraude')
    await adminApi.reactivate(7)
    await adminApi.changeRole(5, 'security_auditor')

    const bodies = vi.mocked(fetch).mock.calls.map(([, init]) => JSON.parse(String(init?.body)))
    expect(bodies).toEqual([
      { reason: 'fraude', confirm: true },
      { confirm: true },
      { role: 'security_auditor', confirm: true },
    ])
    expect(new Headers(vi.mocked(fetch).mock.calls[0]![1]?.headers).get('Content-Type')).toBe('application/json')
  })

  it('maps problems to safe codes and never exposes server detail', async () => {
    vi.mocked(fetch).mockResolvedValue(
      jsonResponse(
        { code: 'last_active_admin_protected', detail: 'secret internal detail' },
        409,
        { 'X-Correlation-ID': 'corr-1' },
      ),
    )

    const error = await adminApi.suspend(7, 'x').catch((value: unknown) => value)

    expect(error).toBeInstanceOf(AdminApiError)
    expect(error).toMatchObject({ status: 409, code: 'last_active_admin_protected', correlationId: 'corr-1', operation: 'suspend' })
    expect(JSON.stringify(error)).not.toContain('secret internal detail')
    expect(safeAdminMessage(error)).toMatch(/sin un administrador activo/)
  })

  it('collapses unknown codes, malformed bodies and network failures to fixed safe codes', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse({ code: 'weird <script>' }, 500))
    vi.mocked(fetch).mockResolvedValueOnce(new Response('not json', { status: 502 }))
    vi.mocked(fetch).mockRejectedValueOnce(new TypeError('offline'))

    const [unknown, malformed, offline] = await Promise.all([
      adminApi.account(1).catch((value: unknown) => value),
      adminApi.account(1).catch((value: unknown) => value),
      adminApi.account(1).catch((value: unknown) => value),
    ])

    expect((unknown as AdminApiError).code).toBe('unknown_error')
    expect((malformed as AdminApiError).code).toBe('unknown_error')
    expect((offline as AdminApiError).code).toBe('network_error')
    expect(safeAdminMessage(offline)).toMatch(/conectar/)
  })

  it('treats an unparseable success body as an invalid response', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ nonsense: true }))

    const error = await adminApi.account(1).catch((value: unknown) => value)

    expect((error as AdminApiError).code).toBe('invalid_response')
  })

  it('reports rate limits with the wait time and a bounded diagnostic', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ code: 'admin_rate_limited' }, 429, { 'Retry-After': '60' }))

    const error = await adminApi.lookupById(5).catch((value: unknown) => value)

    expect(safeAdminMessage(error)).toContain('60 segundos')
    const diagnostic = safeAdminDiagnostic(error, 'lookup')
    expect(diagnostic).toMatchObject({ code: 'admin_rate_limited', operation: 'lookup', status: 429 })
  })

  it('lists escalated tickets with a bounded scope and returns typed rows', async () => {
    vi.mocked(fetch).mockResolvedValue(
      jsonResponse([
        {
          id: 3,
          subject: 'Caso',
          category: 'account',
          created_at: '2026-11-12T12:00:00Z',
          owner_admin_id: null,
          originating_agent_id: 2,
          owned_by_me: false,
        },
      ]),
    )

    const rows = await adminApi.escalated('unclaimed')

    expect(String(vi.mocked(fetch).mock.calls[0]![0])).toBe('/api/v1/staff/admin/tickets/escalated?scope=unclaimed&limit=100')
    expect(rows[0]).toMatchObject({ id: 3, owned_by_me: false })
  })

  it('handles no-content success for replies, resolutions and returns', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(new Response(null, { status: 204 }))
    vi.mocked(fetch).mockResolvedValueOnce(new Response(null, { status: 204 }))
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse({ status: 'open', assigned_staff_user_id: null }))

    await expect(adminApi.reply(3, 'hola')).resolves.toBeUndefined()
    await expect(adminApi.resolve(3, 'listo')).resolves.toBeUndefined()
    await expect(adminApi.returnToSupport(3, 'motivo')).resolves.toEqual({ status: 'open', assigned_staff_user_id: null })
  })
})

export { adminCase }
