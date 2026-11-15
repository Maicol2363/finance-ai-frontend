import { vi } from 'vitest'

export const auditorSession = {
  user: { id: 5, email: 'auditor@example.test', role: 'security_auditor' },
  access_expires_at: '2026-11-11T15:30:00Z',
  renewable_expires_at: '2026-11-12T15:00:00Z',
  absolute_expires_at: '2026-11-18T15:00:00Z',
}

export const supportSession = {
  ...auditorSession,
  user: { id: 6, email: 'agent@example.test', role: 'support_agent' },
}

export const period = {
  start_date: '2026-11-01',
  end_date: '2026-11-14',
  time_zone: 'America/Bogota',
  time_zone_label: 'America/Bogota (UTC-05:00)',
  start_utc: '2026-11-01T05:00:00Z',
  end_utc: '2026-11-15T05:00:00Z',
}

export const catalog = {
  event_types: ['access.denied', 'auth.login_success', 'auth.mfa_failed', 'staff.login', 'staff.login_denied'],
  outcomes: ['success', 'denied', 'failure'],
  target_types: ['account', 'audit_report', 'protected_resource', 'staff_session', 'support_ticket'],
  time_zones: [
    { name: 'America/Bogota', label: 'America/Bogota (UTC-05:00)' },
    { name: 'UTC', label: 'UTC (UTC+00:00)' },
  ],
  default_time_zone: 'America/Bogota',
  max_query_days: 90,
  max_report_events: 2000,
  max_page_size: 100,
  metrics: [],
}

export function auditEvent(overrides: Record<string, unknown> = {}) {
  return {
    event_id: '11111111-1111-4111-8111-111111111111',
    occurred_at: '2026-11-10T15:00:00Z',
    event_type: 'access.denied',
    outcome: 'denied',
    actor_id: '9',
    target_type: 'protected_resource',
    target_id: 'security_audit',
    correlation_id: 'corr-1',
    context: { reason: 'role_not_permitted' },
    ...overrides,
  }
}

export function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'X-Correlation-ID': 'corr-test', ...headers },
  })
}

export function problem(code: string, status: number, extra: Record<string, unknown> = {}): Response {
  return jsonResponse({ code, status, title: 'Request failed', detail: 'safe', correlation_id: 'corr-test', ...extra }, status)
}

type Handler = (url: URL, init?: RequestInit) => Response | Promise<Response> | undefined

/** Routes fetch calls by path; unmatched requests fail loudly so tests never pass by accident. */
export function routeFetch(handler: Handler) {
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input), 'http://127.0.0.1')
    const response = await handler(url, init)
    if (response) return response
    if (url.pathname === '/api/v1/staff/audit/catalog') return jsonResponse(catalog)
    return problem('route_not_found', 404)
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

export function requestedPaths(fetchMock: ReturnType<typeof routeFetch>): string[] {
  return fetchMock.mock.calls.map(([input]) => new URL(String(input), 'http://127.0.0.1').pathname)
}
