const TICKETS_PATH = '/api/v1/staff/support/tickets'

export type TicketStatus = 'open' | 'in_progress' | 'escalated' | 'resolved'
export type SupportOperation = 'queue' | 'detail' | 'claim' | 'lookup' | 'create' | 'conversation' | 'message' | 'escalate' | 'resolve'

export interface SupportTicket {
  id: number
  subject: string
  status: TicketStatus
  created_at: string
  assigned_staff_user_id: number | null
}

export interface SupportTicketDetail extends SupportTicket {
  category: string
  description: string
}

const SAFE_PROBLEM_CODES = new Set([
  'authentication_required',
  'internal_error',
  'invalid_response',
  'network_error',
  'request_timeout',
  'request_too_large',
  'route_not_found',
  'service_unavailable',
  'staff_access_denied',
  'staff_origin_denied',
  'staff_request_denied',
  'support_ticket_claim_conflict',
  'support_ticket_state_conflict',
  'support_ticket_not_found',
  'unknown_error',
  'unsupported_media_type',
  'validation_error',
])
const SAFE_CORRELATION_ID = /^[A-Za-z0-9._-]{1,64}$/

export class SupportTicketsApiError extends Error {
  readonly status: number
  readonly code: string
  readonly correlationId: string | null
  readonly operation: SupportOperation

  constructor(status: number, code: string, correlationId: string | null, operation: SupportOperation) {
    super('No fue posible completar la solicitud de soporte.')
    this.name = 'SupportTicketsApiError'
    this.status = status
    this.code = SAFE_PROBLEM_CODES.has(code) ? code : 'unknown_error'
    this.correlationId = correlationId && SAFE_CORRELATION_ID.test(correlationId) ? correlationId : null
    this.operation = operation
  }
}

async function readProblemCode(response: Response): Promise<string> {
  try {
    const body: unknown = await response.json()
    if (typeof body === 'object' && body !== null && !Array.isArray(body)) {
      const code = (body as Record<string, unknown>).code
      if (typeof code === 'string' && SAFE_PROBLEM_CODES.has(code)) return code
    }
  } catch {
    // An unreadable problem response receives a fixed safe code.
  }
  return 'unknown_error'
}

async function request<T>(operation: SupportOperation, path: string, init?: RequestInit): Promise<T> {
  const requestId = crypto.randomUUID()
  try {
    const response = await fetch(`${TICKETS_PATH}${path}`, {
      ...init,
      cache: 'no-store',
      credentials: 'include',
      headers: {
        Accept: 'application/json',
        'X-Staff-Request': '1',
        'X-Correlation-ID': requestId,
        ...init?.headers,
      },
    })
    const responseId = response.headers.get('X-Correlation-ID')
    const correlationId = responseId && SAFE_CORRELATION_ID.test(responseId) ? responseId : requestId
    if (!response.ok) {
      throw new SupportTicketsApiError(response.status, await readProblemCode(response), correlationId, operation)
    }
    if (response.status === 204) return undefined as T
    try {
      return (await response.json()) as T
    } catch {
      throw new SupportTicketsApiError(0, 'invalid_response', correlationId, operation)
    }
  } catch (error) {
    if (error instanceof SupportTicketsApiError) throw error
    throw new SupportTicketsApiError(0, 'network_error', requestId, operation)
  }
}

export interface SupportDiagnostic {
  code: string
  operation: SupportOperation
  occurredAtUtc: string
  platform: 'web'
  apiLocation: string
  correlationId: string | null
  reason: string
}

const SAFE_DIAGNOSTIC_REASONS: Record<string, string> = {
  authentication_required: 'authentication_required',
  internal_error: 'server_error',
  invalid_response: 'invalid_server_response',
  network_error: 'network_unavailable',
  request_timeout: 'request_timed_out',
  request_too_large: 'request_rejected',
  route_not_found: 'api_route_unavailable',
  service_unavailable: 'service_unavailable',
  staff_access_denied: 'staff_access_denied',
  staff_origin_denied: 'request_origin_denied',
  staff_request_denied: 'request_denied',
  support_ticket_claim_conflict: 'claim_conflict',
  support_ticket_state_conflict: 'ticket_state_conflict',
  support_ticket_not_found: 'ticket_unavailable',
  unknown_error: 'unknown_error',
  unsupported_media_type: 'unsupported_request_format',
  validation_error: 'request_validation_failed',
  unclassified_error: 'unclassified_error',
}

function supportApiLocation(operation: SupportOperation): string {
  if (operation === 'lookup') return `${TICKETS_PATH}/customer-lookup`
  if (operation === 'conversation') return `${TICKETS_PATH}/{ticket_id}/conversation`
  if (operation === 'message') return `${TICKETS_PATH}/{ticket_id}/messages`
  if (operation === 'escalate' || operation === 'resolve') return `${TICKETS_PATH}/{ticket_id}/${operation}`
  if (operation === 'detail') return `${TICKETS_PATH}/{ticket_id}`
  if (operation === 'claim') return `${TICKETS_PATH}/{ticket_id}/claim`
  return TICKETS_PATH
}

export function safeSupportDiagnostic(error: unknown, fallbackOperation: SupportOperation): SupportDiagnostic {
  const apiError = error instanceof SupportTicketsApiError ? error : null
  const code = apiError ? apiError.code : 'unclassified_error'
  const operation = apiError?.operation ?? fallbackOperation
  return {
    code,
    operation,
    occurredAtUtc: new Date().toISOString(),
    platform: 'web',
    apiLocation: supportApiLocation(operation),
    correlationId: apiError?.correlationId ?? null,
    reason: SAFE_DIAGNOSTIC_REASONS[code] ?? SAFE_DIAGNOSTIC_REASONS.unclassified_error,
  }
}

export function safeSupportMessage(error: unknown, operation: SupportOperation): string {
  if (error instanceof SupportTicketsApiError && error.code === 'support_ticket_claim_conflict') {
    return 'Otro agente reclamó este ticket primero. Actualiza la cola para ver su asignación.'
  }
  if (error instanceof SupportTicketsApiError && error.code === 'route_not_found') {
    return 'El servicio todavía no ofrece esta operación. Comparte el informe de diagnóstico con soporte.'
  }
  if (error instanceof SupportTicketsApiError && error.status === 409) return 'El estado del ticket cambió. Actualiza antes de continuar.'
  if (operation === 'queue') return 'No se pudo cargar la cola. Comprueba tu sesión e inténtalo de nuevo.'
  if (operation === 'lookup') return `${TICKETS_PATH}/customer-lookup`
  if (operation === 'conversation') return `${TICKETS_PATH}/{ticket_id}/conversation`
  if (operation === 'message') return `${TICKETS_PATH}/{ticket_id}/messages`
  if (operation === 'escalate' || operation === 'resolve') return `${TICKETS_PATH}/{ticket_id}/${operation}`
  if (operation === 'detail') return 'No fue posible abrir el contexto autorizado del ticket.'
  return 'No se pudo completar la operación. Verifica tu sesión y actualiza el ticket.'
}

export interface SupportCustomer { id: number; email: string; is_active: boolean }
export interface SupportConversation {
  ticket: SupportTicketDetail & { resolution_summary: string | null }
  customer: SupportCustomer
  messages: Array<{ id: number; author_user_id: number; body: string; created_at: string }>
  history: Array<{ id: number; actor_user_id: number; event_type: string; created_at: string; previous_status: string | null; new_status: string | null; new_assignee_user_id: number | null; internal_reason?: string | null }>
}

export const supportTicketsApi = {
  lookup(identifier: string): Promise<SupportCustomer> {
    return request('lookup', '/customer-lookup', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ identifier }) })
  },
  create(data: { customer_identifier: string; subject: string; category: string; description: string }): Promise<SupportTicket> {
    return request('create', '', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
  },
  conversation(id: number, signal?: AbortSignal): Promise<SupportConversation> {
    return request('conversation', `/${id}/conversation`, { method: 'GET', signal })
  },
  action(id: number, kind: 'message' | 'escalate' | 'resolve', data: { body: string } | { summary: string }): Promise<void> {
    return request(kind, `/${id}/${kind === 'message' ? 'messages' : kind}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
  },
  list(status: TicketStatus | 'all', signal?: AbortSignal): Promise<SupportTicket[]> {
    const query = status === 'all' ? '' : `?status=${encodeURIComponent(status)}`
    return request('queue', query, { method: 'GET', signal })
  },

  detail(id: number, signal?: AbortSignal): Promise<SupportTicketDetail> {
    return request('detail', `/${id}`, { method: 'GET', signal })
  },

  claim(id: number): Promise<SupportTicket> {
    return request('claim', `/${id}/claim`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    })
  },
}
