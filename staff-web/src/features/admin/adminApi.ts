/**
 * Typed client for the Administrator API (`/api/v1/staff/admin`). The backend is the only
 * authority: every response is validated against the published contract, errors reduce to a
 * fixed set of safe codes plus a correlation ID, and no credential is ever read from or kept
 * in browser storage (the session is the HttpOnly cookie).
 */
const ADMIN_PATH = '/api/v1/staff/admin'
const REQUEST_TIMEOUT_MS = 20_000
const SAFE_CORRELATION_ID = /^[A-Za-z0-9._-]{1,64}$/

export type AdminOperation =
  | 'lookup'
  | 'account'
  | 'suspend'
  | 'reactivate'
  | 'invite'
  | 'staff'
  | 'role'
  | 'queue'
  | 'case'
  | 'claim'
  | 'reply'
  | 'resolve'
  | 'return'

/** Sanitized endpoint templates for diagnostic reports: never a real id or query value. */
export const ADMIN_API_LOCATIONS: Readonly<Record<AdminOperation, string>> = {
  lookup: '/api/v1/staff/admin/accounts/lookup',
  account: '/api/v1/staff/admin/accounts/{id}',
  suspend: '/api/v1/staff/admin/accounts/{id}/suspend',
  reactivate: '/api/v1/staff/admin/accounts/{id}/reactivate',
  invite: '/api/v1/staff/admin/staff/invitations',
  staff: '/api/v1/staff/admin/staff/{id}',
  role: '/api/v1/staff/admin/staff/{id}/role',
  queue: '/api/v1/staff/admin/tickets/escalated',
  case: '/api/v1/staff/admin/tickets/{id}',
  claim: '/api/v1/staff/admin/tickets/{id}/claim',
  reply: '/api/v1/staff/admin/tickets/{id}/messages',
  resolve: '/api/v1/staff/admin/tickets/{id}/resolve',
  return: '/api/v1/staff/admin/tickets/{id}/return',
}

const SAFE_PROBLEM_CODES = new Set([
  'access_expired',
  'account_not_found',
  'account_state_conflict',
  'admin_rate_limited',
  'admin_request_invalid',
  'admin_self_action_denied',
  'audit_unavailable',
  'authentication_required',
  'escalation_claim_conflict',
  'internal_error',
  'invalid_response',
  'last_active_admin_protected',
  'network_error',
  'request_invalid',
  'request_timeout',
  'request_too_large',
  'role_change_not_allowed',
  'route_not_found',
  'service_unavailable',
  'session_invalid',
  'staff_access_denied',
  'staff_email_unavailable',
  'staff_origin_denied',
  'staff_request_denied',
  'support_ticket_not_found',
  'support_ticket_state_conflict',
  'unknown_error',
  'unsupported_media_type',
  'validation_error',
])

export class AdminApiError extends Error {
  readonly status: number
  readonly code: string
  readonly correlationId: string | null
  readonly operation: AdminOperation
  readonly retryAfterSeconds: number | null

  constructor(
    status: number,
    code: string,
    correlationId: string | null,
    operation: AdminOperation,
    retryAfterSeconds: number | null = null,
  ) {
    super('La solicitud de administración no se pudo completar.')
    this.name = 'AdminApiError'
    this.status = status
    this.code = SAFE_PROBLEM_CODES.has(code) ? code : 'unknown_error'
    this.correlationId = correlationId && SAFE_CORRELATION_ID.test(correlationId) ? correlationId : null
    this.operation = operation
    this.retryAfterSeconds = retryAfterSeconds
  }
}

// --- contract types ---------------------------------------------------------------------------

export type AccountStatus = 'active' | 'suspended'
export type PortalStaffRole = 'support_agent' | 'security_auditor'
export type EscalationScope = 'all' | 'unclaimed' | 'mine'

export interface SuspensionRecord {
  reason: string
  suspended_at: string
  suspended_by_user_id: number
}

/** A login account (never a financial account). */
export interface AdminAccount {
  id: number
  email: string
  role: string
  status: AccountStatus
  registered_at: string
  account_type: 'login_account'
  suspension: SuspensionRecord | null
}

export interface StaffInvitationCreated {
  invitation_id: number
  email: string
  role: PortalStaffRole
  expires_at: string
  /** Shown once; never persisted by the browser. */
  activation_token: string
}

export interface StaffAccount {
  id: number
  email: string
  role: string
  status: AccountStatus
  registered_at: string
  account_type: 'login_account'
  assignable_roles: PortalStaffRole[]
}

export interface EscalatedTicketItem {
  id: number
  subject: string
  category: string
  created_at: string
  owner_admin_id: number | null
  originating_agent_id: number | null
  owned_by_me: boolean
}

export interface CaseMessage {
  id: number
  author_user_id: number
  body: string
  created_at: string
}

export interface CaseHistoryEntry {
  id: number
  actor_user_id: number
  event_type: string
  previous_status: string | null
  new_status: string | null
  previous_assignee_user_id: number | null
  new_assignee_user_id: number | null
  created_at: string
  /** Staff-only workflow metadata; never shown to customers. */
  internal_reason: string | null
}

export interface AdminCase {
  ticket: {
    id: number
    subject: string
    category: string
    description: string
    status: string
    created_at: string
    assigned_staff_user_id: number | null
    resolution_summary: string | null
  }
  customer: { id: number; email: string; is_active: boolean }
  messages: CaseMessage[]
  history: CaseHistoryEntry[]
  escalation_reason: string | null
  owner_admin_id: number | null
  owned_by_me: boolean
  originating_agent: { user_id: number | null; can_receive_return: boolean }
}

export interface ReturnTicketResult {
  status: 'in_progress' | 'open'
  assigned_staff_user_id: number | null
}

// --- parsing ----------------------------------------------------------------------------------

type JsonObject = Record<string, unknown>

function invalid(): never {
  throw new AdminApiError(0, 'invalid_response', null, 'account')
}

function obj(value: unknown): JsonObject {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return invalid()
  return value as JsonObject
}

function str(value: unknown, max = 10_000): string {
  if (typeof value !== 'string' || value.length > max) return invalid()
  return value
}

function nullableStr(value: unknown, max = 10_000): string | null {
  return value === null ? null : str(value, max)
}

function int(value: unknown): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 1) return invalid()
  return value
}

function nullableInt(value: unknown): number | null {
  return value === null ? null : int(value)
}

function bool(value: unknown): boolean {
  if (typeof value !== 'boolean') return invalid()
  return value
}

function dateTime(value: unknown): string {
  const text = str(value, 64)
  if (!Number.isFinite(Date.parse(text))) return invalid()
  return text
}

function list<T>(value: unknown, parse: (item: unknown) => T, max = 500): T[] {
  if (!Array.isArray(value) || value.length > max) return invalid()
  return value.map(parse)
}

function oneOf<T extends string>(value: unknown, allowed: readonly T[]): T {
  if (typeof value !== 'string' || !(allowed as readonly string[]).includes(value)) return invalid()
  return value as T
}

const PORTAL_ROLES = ['support_agent', 'security_auditor'] as const

export function parseAdminAccount(value: unknown): AdminAccount {
  const data = obj(value)
  const suspension = data.suspension === null || data.suspension === undefined ? null : obj(data.suspension)
  return {
    id: int(data.id),
    email: str(data.email, 320),
    role: str(data.role, 50),
    status: oneOf(data.status, ['active', 'suspended'] as const),
    registered_at: dateTime(data.registered_at),
    account_type: oneOf(data.account_type, ['login_account'] as const),
    suspension: suspension
      ? {
          reason: str(suspension.reason, 500),
          suspended_at: dateTime(suspension.suspended_at),
          suspended_by_user_id: int(suspension.suspended_by_user_id),
        }
      : null,
  }
}

export function parseStaffInvitation(value: unknown): StaffInvitationCreated {
  const data = obj(value)
  return {
    invitation_id: int(data.invitation_id),
    email: str(data.email, 320),
    role: oneOf(data.role, PORTAL_ROLES),
    expires_at: dateTime(data.expires_at),
    activation_token: ((token) => (/^[A-Za-z0-9_-]{43}$/.test(token) ? token : invalid()))(str(data.activation_token, 64)),
  }
}

export function parseStaffAccount(value: unknown): StaffAccount {
  const data = obj(value)
  return {
    id: int(data.id),
    email: str(data.email, 320),
    role: str(data.role, 50),
    status: oneOf(data.status, ['active', 'suspended'] as const),
    registered_at: dateTime(data.registered_at),
    account_type: oneOf(data.account_type, ['login_account'] as const),
    assignable_roles: list(data.assignable_roles, (role) => oneOf(role, PORTAL_ROLES), 2),
  }
}

export function parseEscalatedTicket(value: unknown): EscalatedTicketItem {
  const data = obj(value)
  return {
    id: int(data.id),
    subject: str(data.subject, 500),
    category: str(data.category, 100),
    created_at: dateTime(data.created_at),
    owner_admin_id: nullableInt(data.owner_admin_id),
    originating_agent_id: nullableInt(data.originating_agent_id),
    owned_by_me: bool(data.owned_by_me),
  }
}

export function parseAdminCase(value: unknown): AdminCase {
  const data = obj(value)
  const ticket = obj(data.ticket)
  const customer = obj(data.customer)
  const origin = obj(data.originating_agent)
  return {
    ticket: {
      id: int(ticket.id),
      subject: str(ticket.subject, 500),
      category: str(ticket.category, 100),
      description: str(ticket.description, 20_000),
      status: str(ticket.status, 20),
      created_at: dateTime(ticket.created_at),
      assigned_staff_user_id: nullableInt(ticket.assigned_staff_user_id),
      resolution_summary: nullableStr(ticket.resolution_summary, 20_000),
    },
    customer: { id: int(customer.id), email: str(customer.email, 320), is_active: bool(customer.is_active) },
    messages: list(data.messages, (item) => {
      const message = obj(item)
      return {
        id: int(message.id),
        author_user_id: int(message.author_user_id),
        body: str(message.body, 20_000),
        created_at: dateTime(message.created_at),
      }
    }),
    history: list(data.history, (item) => {
      const entry = obj(item)
      return {
        id: int(entry.id),
        actor_user_id: int(entry.actor_user_id),
        event_type: str(entry.event_type, 48),
        previous_status: nullableStr(entry.previous_status, 20),
        new_status: nullableStr(entry.new_status, 20),
        previous_assignee_user_id: nullableInt(entry.previous_assignee_user_id),
        new_assignee_user_id: nullableInt(entry.new_assignee_user_id),
        created_at: dateTime(entry.created_at),
        internal_reason: nullableStr(entry.internal_reason, 20_000),
      }
    }),
    escalation_reason: nullableStr(data.escalation_reason, 20_000),
    owner_admin_id: nullableInt(data.owner_admin_id),
    owned_by_me: bool(data.owned_by_me),
    originating_agent: {
      user_id: nullableInt(origin.user_id),
      can_receive_return: bool(origin.can_receive_return),
    },
  }
}

export function parseReturnResult(value: unknown): ReturnTicketResult {
  const data = obj(value)
  return {
    status: oneOf(data.status, ['in_progress', 'open'] as const),
    assigned_staff_user_id: nullableInt(data.assigned_staff_user_id),
  }
}

// --- transport --------------------------------------------------------------------------------

function parseRetryAfter(value: string | null): number | null {
  const seconds = Number(value)
  return value && Number.isFinite(seconds) ? Math.min(3600, Math.max(1, Math.ceil(seconds))) : null
}

async function readProblemCode(response: Response): Promise<string> {
  try {
    const body: unknown = await response.json()
    if (typeof body === 'object' && body !== null && !Array.isArray(body)) {
      const code = (body as JsonObject).code
      if (typeof code === 'string' && SAFE_PROBLEM_CODES.has(code)) return code
    }
  } catch {
    // An unreadable problem response receives a fixed safe code.
  }
  return 'unknown_error'
}

async function request<T>(
  operation: AdminOperation,
  path: string,
  init: { method: 'GET' | 'POST'; body?: unknown; signal?: AbortSignal },
  parse: (value: unknown) => T,
): Promise<T> {
  const requestId = crypto.randomUUID()
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS)
  init.signal?.addEventListener('abort', () => controller.abort(), { once: true })
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'X-Staff-Request': '1',
    'X-Correlation-ID': requestId,
  }
  if (init.method === 'POST') headers['Content-Type'] = 'application/json'
  try {
    const response = await fetch(`${ADMIN_PATH}${path}`, {
      method: init.method,
      body: init.method === 'POST' ? JSON.stringify(init.body ?? {}) : undefined,
      cache: 'no-store',
      credentials: 'include',
      headers,
      signal: controller.signal,
    })
    const responseId = response.headers.get('X-Correlation-ID')
    const correlationId = responseId && SAFE_CORRELATION_ID.test(responseId) ? responseId : requestId
    if (!response.ok) {
      throw new AdminApiError(
        response.status,
        await readProblemCode(response),
        correlationId,
        operation,
        parseRetryAfter(response.headers.get('Retry-After')),
      )
    }
    if (response.status === 204) return undefined as T
    try {
      return parse(await response.json())
    } catch {
      throw new AdminApiError(0, 'invalid_response', correlationId, operation)
    }
  } catch (error) {
    if (error instanceof AdminApiError) {
      throw new AdminApiError(error.status, error.code, error.correlationId ?? requestId, operation, error.retryAfterSeconds)
    }
    if (controller.signal.aborted && !init.signal?.aborted) throw new AdminApiError(0, 'request_timeout', requestId, operation)
    throw new AdminApiError(0, 'network_error', requestId, operation)
  } finally {
    clearTimeout(timeoutId)
  }
}

const noContent = (): void => undefined

export const adminApi = {
  // The email goes in the JSON body, never in a URL that proxies and browsers log.
  lookupByEmail(email: string, signal?: AbortSignal): Promise<AdminAccount> {
    return request('lookup', '/accounts/lookup', { method: 'POST', body: { email }, signal }, parseAdminAccount)
  },
  lookupById(id: number, signal?: AbortSignal): Promise<AdminAccount> {
    return request('lookup', '/accounts/lookup', { method: 'POST', body: { id }, signal }, parseAdminAccount)
  },
  account(id: number, signal?: AbortSignal): Promise<AdminAccount> {
    return request('account', `/accounts/${id}`, { method: 'GET', signal }, parseAdminAccount)
  },
  suspend(id: number, reason: string): Promise<AdminAccount> {
    return request('suspend', `/accounts/${id}/suspend`, { method: 'POST', body: { reason, confirm: true } }, parseAdminAccount)
  },
  reactivate(id: number): Promise<AdminAccount> {
    return request('reactivate', `/accounts/${id}/reactivate`, { method: 'POST', body: { confirm: true } }, parseAdminAccount)
  },
  invite(email: string, role: PortalStaffRole): Promise<StaffInvitationCreated> {
    return request('invite', '/staff/invitations', { method: 'POST', body: { email, role } }, parseStaffInvitation)
  },
  staff(id: number, signal?: AbortSignal): Promise<StaffAccount> {
    return request('staff', `/staff/${id}`, { method: 'GET', signal }, parseStaffAccount)
  },
  changeRole(id: number, role: PortalStaffRole): Promise<StaffAccount> {
    return request('role', `/staff/${id}/role`, { method: 'POST', body: { role, confirm: true } }, parseStaffAccount)
  },
  escalated(scope: EscalationScope, signal?: AbortSignal): Promise<EscalatedTicketItem[]> {
    return request('queue', `/tickets/escalated?scope=${scope}&limit=100`, { method: 'GET', signal }, (value) =>
      list(value, parseEscalatedTicket, 100),
    )
  },
  case(id: number, signal?: AbortSignal): Promise<AdminCase> {
    return request('case', `/tickets/${id}`, { method: 'GET', signal }, parseAdminCase)
  },
  claim(id: number): Promise<AdminCase> {
    return request('claim', `/tickets/${id}/claim`, { method: 'POST', body: {} }, parseAdminCase)
  },
  reply(id: number, body: string): Promise<void> {
    return request('reply', `/tickets/${id}/messages`, { method: 'POST', body: { body } }, noContent)
  },
  resolve(id: number, summary: string): Promise<void> {
    return request('resolve', `/tickets/${id}/resolve`, { method: 'POST', body: { summary } }, noContent)
  },
  returnToSupport(id: number, reason: string): Promise<ReturnTicketResult> {
    return request('return', `/tickets/${id}/return`, { method: 'POST', body: { reason } }, parseReturnResult)
  },
}

// --- safe presentation --------------------------------------------------------------------------

export interface AdminDiagnostic {
  code: string
  operation: AdminOperation
  status: number
  correlationId: string | null
  occurredAtUtc: string
}

export function safeAdminDiagnostic(error: unknown, operation: AdminOperation): AdminDiagnostic {
  const apiError = error instanceof AdminApiError ? error : null
  return {
    code: apiError?.code ?? 'unknown_error',
    operation: apiError?.operation ?? operation,
    status: apiError?.status ?? 0,
    correlationId: apiError?.correlationId ?? null,
    occurredAtUtc: new Date().toISOString(),
  }
}

const MESSAGES: Record<string, string> = {
  account_not_found: 'No hay ninguna cuenta de acceso con ese dato.',
  account_state_conflict: 'La cuenta ya está en ese estado. Actualiza e inténtalo de nuevo.',
  admin_rate_limited: 'Demasiadas solicitudes. Espera un momento antes de continuar.',
  admin_request_invalid: 'Revisa los datos ingresados e inténtalo de nuevo.',
  admin_self_action_denied: 'No puedes realizar esta acción sobre tu propia cuenta.',
  audit_unavailable: 'No se pudo registrar la evidencia de seguridad, así que el cambio no se aplicó. Inténtalo de nuevo.',
  escalation_claim_conflict: 'Otro administrador tomó este caso primero o ya no está escalado. Actualiza la lista.',
  last_active_admin_protected: 'Este cambio dejaría al sistema sin un administrador activo, por eso no se permite.',
  request_invalid: 'Revisa los datos ingresados e inténtalo de nuevo.',
  role_change_not_allowed: 'Solo se puede alternar el rol entre agente de soporte y auditor de seguridad. Los administradores y clientes no se modifican aquí.',
  staff_access_denied: 'Tu sesión ya no tiene permiso de administración. Inicia sesión de nuevo.',
  staff_email_unavailable: 'Ya existe una cuenta o una invitación vigente para ese correo.',
  support_ticket_not_found: 'El caso no existe o ya no está escalado.',
  support_ticket_state_conflict: 'El caso cambió de estado o pertenece a otro administrador. Actualiza antes de continuar.',
}

export function safeAdminMessage(error: unknown): string {
  if (error instanceof AdminApiError) {
    if (error.status === 429 && error.retryAfterSeconds) {
      return `Demasiadas solicitudes. Vuelve a intentarlo en ${error.retryAfterSeconds} segundos.`
    }
    const message = MESSAGES[error.code]
    if (message) return message
    if (error.code === 'network_error' || error.code === 'request_timeout') {
      return 'No se pudo conectar con el servicio. Comprueba tu conexión e inténtalo de nuevo.'
    }
    if (error.code === 'authentication_required' || error.code === 'access_expired') {
      return 'Tu sesión se está renovando. Vuelve a intentarlo en unos segundos.'
    }
    if (error.code === 'session_invalid') {
      return 'Tu sesión ya no es válida. Inicia sesión de nuevo.'
    }
  }
  return 'No se pudo completar la operación. Inténtalo de nuevo.'
}

/** Errors after which the current session must be re-confirmed by the session coordinator. */
export function needsSessionCheck(error: unknown): boolean {
  return error instanceof AdminApiError && (error.status === 401 || error.status === 403)
}
