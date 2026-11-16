const AUDIT_PATH = '/api/v1/staff/audit'
const REQUEST_TIMEOUT_MS = 20_000
const REPORT_TIMEOUT_MS = 120_000
const SAFE_CORRELATION_ID = /^[A-Za-z0-9._-]{1,64}$/
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/
const DATE_TIME_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/i
const REPORT_FILENAME = /^informe-auditoria-[0-9a-f-]{36}\.pdf$/i

export type AuditOperation = 'catalog' | 'events' | 'event' | 'investigation' | 'summary' | 'report'
export type AuditTimeZone = 'America/Bogota' | 'UTC'
export type AuditMatch = 'actor' | 'target' | 'actor_and_target'
export type AuditCoverage = 'available' | 'partial' | 'no_records'

export interface AuditPeriodQuery {
  start_date: string
  end_date: string
  time_zone: AuditTimeZone
}

export interface AuditFilterQuery {
  event_type?: string
  outcome?: string
  actor_id?: string
  actor_role?: string
  target_type?: string
  target_id?: string
  correlation_id?: string
}

export const FILTER_KEYS = ['event_type', 'outcome', 'actor_id', 'actor_role', 'target_type', 'target_id', 'correlation_id'] as const

export interface AuditPeriod {
  start_date: string
  end_date: string
  time_zone: string
  time_zone_label: string
  start_utc: string
  end_utc: string
}

export interface AuditEvent {
  event_id: string
  occurred_at: string
  event_type: string
  outcome: string
  actor_id: string | null
  /** Role the actor held when the event was recorded; null when not recorded. */
  actor_role: string | null
  target_type: string | null
  target_id: string | null
  correlation_id: string | null
  context: Record<string, string>
}

export interface AuditEventPage {
  items: AuditEvent[]
  next_cursor: string | null
  read_boundary: string
  period: AuditPeriod
}

export interface AuditInvestigationEvent extends AuditEvent {
  match: AuditMatch
}

export interface AuditInvestigationPage {
  account_id: string
  items: AuditInvestigationEvent[]
  next_cursor: string | null
  read_boundary: string
  period: AuditPeriod
}

export interface AuditMetricMapping {
  event_type: string
  outcomes: string[]
}

export interface AuditMetricDefinition {
  key: string
  label: string
  description: string
  mapping: AuditMetricMapping[]
}

export interface AuditMetric extends AuditMetricDefinition {
  count: number
}

export interface AuditTypeCount {
  event_type: string
  outcome: string
  count: number
}

export interface AuditDayCount {
  date: string
  count: number
}

export interface AuditSummary {
  period: AuditPeriod
  cutoff: string
  total_events: number
  metrics: AuditMetric[]
  by_type: AuditTypeCount[]
  by_day: AuditDayCount[]
  earliest_recorded_at: string | null
  coverage: AuditCoverage
}

export interface AuditCatalog {
  event_types: string[]
  outcomes: string[]
  target_types: string[]
  actor_roles: string[]
  time_zones: Array<{ name: AuditTimeZone; label: string }>
  default_time_zone: AuditTimeZone
  max_query_days: number
  max_report_events: number
  max_page_size: number
  metrics: AuditMetricDefinition[]
}

export interface AuditReportFile {
  blob: Blob
  filename: string
  reportId: string
  eventCount: number
}

const SAFE_PROBLEM_CODES = new Set([
  'access_expired',
  'audit_event_not_found',
  'audit_export_unrecorded',
  'audit_period_too_long',
  'audit_query_invalid',
  'audit_query_unavailable',
  'audit_rate_limited',
  'audit_report_generation_failed',
  'audit_report_too_large',
  'audit_unavailable',
  'authentication_required',
  'internal_error',
  'request_invalid',
  'request_too_large',
  'route_not_found',
  'service_unavailable',
  'session_invalid',
  'staff_access_denied',
  'staff_origin_denied',
  'staff_request_denied',
  'unsupported_media_type',
])
const SAFE_FIELD_NAMES = new Set([
  'start_date',
  'end_date',
  'time_zone',
  'event_type',
  'outcome',
  'actor_id',
  'actor_role',
  'target_type',
  'target_id',
  'correlation_id',
  'cursor',
  'limit',
  'account_id',
])

export class AuditApiError extends Error {
  readonly status: number
  readonly code: string
  readonly correlationId: string | null
  readonly operation: AuditOperation
  readonly fields: string[]

  constructor(status: number, code: string, correlationId: string | null, operation: AuditOperation, fields: string[] = []) {
    super('No fue posible completar la solicitud de auditoría.')
    this.name = 'AuditApiError'
    this.status = status
    this.code = SAFE_PROBLEM_CODES.has(code) || code === 'invalid_response' || code === 'network_error' || code === 'request_timeout'
      ? code
      : 'unknown_error'
    this.correlationId = correlationId && SAFE_CORRELATION_ID.test(correlationId) ? correlationId : null
    this.operation = operation
    this.fields = fields.filter((field) => SAFE_FIELD_NAMES.has(field))
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isDateTime(value: unknown): value is string {
  return typeof value === 'string' && DATE_TIME_PATTERN.test(value) && Number.isFinite(Date.parse(value))
}

function isDate(value: unknown): value is string {
  return typeof value === 'string' && DATE_PATTERN.test(value)
}

function isCount(value: unknown): value is number {
  return Number.isSafeInteger(value) && Number(value) >= 0
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === 'string'
}

function isStringList(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string')
}

class InvalidResponse extends Error {}

function ensure(condition: boolean): asserts condition {
  if (!condition) throw new InvalidResponse()
}

function requireDateTime(value: unknown): string {
  ensure(isDateTime(value))
  return value
}

function parsePeriod(value: unknown): AuditPeriod {
  ensure(isRecord(value))
  ensure(isDate(value.start_date) && isDate(value.end_date))
  ensure(typeof value.time_zone === 'string' && typeof value.time_zone_label === 'string')
  ensure(isDateTime(value.start_utc) && isDateTime(value.end_utc))
  return {
    start_date: value.start_date,
    end_date: value.end_date,
    time_zone: value.time_zone,
    time_zone_label: value.time_zone_label,
    start_utc: value.start_utc,
    end_utc: value.end_utc,
  }
}

function parseContext(value: unknown): Record<string, string> {
  ensure(isRecord(value))
  const context: Record<string, string> = {}
  for (const [key, item] of Object.entries(value)) {
    ensure(typeof item === 'string')
    context[key] = item
  }
  return context
}

export function parseAuditEvent(value: unknown): AuditEvent {
  ensure(isRecord(value))
  ensure(typeof value.event_id === 'string' && UUID_PATTERN.test(value.event_id))
  ensure(isDateTime(value.occurred_at))
  ensure(typeof value.event_type === 'string' && typeof value.outcome === 'string')
  ensure(isNullableString(value.actor_id) && isNullableString(value.target_type))
  ensure(isNullableString(value.target_id) && isNullableString(value.correlation_id))
  // Tolerates a backend that predates the recorded role: absent means not recorded.
  const actorRole: unknown = value.actor_role === undefined ? null : value.actor_role
  ensure(isNullableString(actorRole))
  return {
    event_id: value.event_id,
    occurred_at: value.occurred_at,
    event_type: value.event_type,
    outcome: value.outcome,
    actor_id: value.actor_id,
    actor_role: actorRole,
    target_type: value.target_type,
    target_id: value.target_id,
    correlation_id: value.correlation_id,
    context: parseContext(value.context),
  }
}

function parseCursor(value: unknown): string | null {
  if (value === null) return null
  ensure(typeof value === 'string' && /^[A-Za-z0-9_-]{1,512}$/.test(value))
  return value
}

export function parseEventPage(value: unknown): AuditEventPage {
  ensure(isRecord(value) && Array.isArray(value.items) && isDateTime(value.read_boundary))
  return {
    items: value.items.map(parseAuditEvent),
    next_cursor: parseCursor(value.next_cursor),
    read_boundary: value.read_boundary,
    period: parsePeriod(value.period),
  }
}

export function parseInvestigationPage(value: unknown): AuditInvestigationPage {
  ensure(isRecord(value) && Array.isArray(value.items) && isDateTime(value.read_boundary))
  ensure(typeof value.account_id === 'string')
  return {
    account_id: value.account_id,
    items: value.items.map((item) => {
      ensure(isRecord(item) && (item.match === 'actor' || item.match === 'target' || item.match === 'actor_and_target'))
      return { ...parseAuditEvent(item), match: item.match }
    }),
    next_cursor: parseCursor(value.next_cursor),
    read_boundary: value.read_boundary,
    period: parsePeriod(value.period),
  }
}

function parseMetricDefinition(value: unknown): AuditMetricDefinition {
  ensure(isRecord(value) && typeof value.key === 'string' && typeof value.label === 'string')
  ensure(typeof value.description === 'string' && Array.isArray(value.mapping))
  return {
    key: value.key,
    label: value.label,
    description: value.description,
    mapping: value.mapping.map((item) => {
      ensure(isRecord(item) && typeof item.event_type === 'string' && isStringList(item.outcomes))
      return { event_type: item.event_type, outcomes: item.outcomes }
    }),
  }
}

export function parseSummary(value: unknown): AuditSummary {
  ensure(isRecord(value) && isDateTime(value.cutoff) && isCount(value.total_events))
  ensure(Array.isArray(value.metrics) && Array.isArray(value.by_type) && Array.isArray(value.by_day))
  const earliest = value.earliest_recorded_at === null ? null : requireDateTime(value.earliest_recorded_at)
  ensure(value.coverage === 'available' || value.coverage === 'partial' || value.coverage === 'no_records')
  return {
    period: parsePeriod(value.period),
    cutoff: value.cutoff,
    total_events: value.total_events,
    metrics: value.metrics.map((item) => {
      ensure(isRecord(item) && isCount(item.count))
      return { ...parseMetricDefinition(item), count: item.count }
    }),
    by_type: value.by_type.map((item) => {
      ensure(isRecord(item) && typeof item.event_type === 'string' && typeof item.outcome === 'string' && isCount(item.count))
      return { event_type: item.event_type, outcome: item.outcome, count: item.count }
    }),
    by_day: value.by_day.map((item) => {
      ensure(isRecord(item) && isDate(item.date) && isCount(item.count))
      return { date: item.date, count: item.count }
    }),
    earliest_recorded_at: earliest,
    coverage: value.coverage,
  }
}

function isTimeZone(value: unknown): value is AuditTimeZone {
  return value === 'America/Bogota' || value === 'UTC'
}

export function parseCatalog(value: unknown): AuditCatalog {
  ensure(isRecord(value))
  ensure(isStringList(value.event_types) && isStringList(value.outcomes) && isStringList(value.target_types))
  ensure(Array.isArray(value.time_zones) && isTimeZone(value.default_time_zone))
  ensure(isCount(value.max_query_days) && isCount(value.max_report_events) && isCount(value.max_page_size))
  ensure(Array.isArray(value.metrics))
  const actorRoles: unknown = value.actor_roles === undefined ? [] : value.actor_roles
  ensure(isStringList(actorRoles))
  return {
    event_types: value.event_types,
    outcomes: value.outcomes,
    target_types: value.target_types,
    actor_roles: actorRoles,
    time_zones: value.time_zones.map((item) => {
      ensure(isRecord(item) && isTimeZone(item.name) && typeof item.label === 'string')
      return { name: item.name, label: item.label }
    }),
    default_time_zone: value.default_time_zone,
    max_query_days: value.max_query_days,
    max_report_events: value.max_report_events,
    max_page_size: value.max_page_size,
    metrics: value.metrics.map(parseMetricDefinition),
  }
}

async function readProblem(response: Response, signal: AbortSignal): Promise<{ code: string; fields: string[] }> {
  try {
    const body: unknown = await response.json()
    if (isRecord(body) && typeof body.code === 'string') {
      const fields = isRecord(body.field_errors) ? Object.keys(body.field_errors) : []
      return { code: body.code, fields }
    }
  } catch (error) {
    if (signal.aborted) throw error
    // An unreadable problem body receives a fixed safe code.
  }
  return { code: 'unknown_error', fields: [] }
}

async function send<T>(
  operation: AuditOperation,
  path: string,
  init: RequestInit,
  timeoutMs: number,
  consume: (response: Response, correlationId: string, signal: AbortSignal) => Promise<T>,
): Promise<T> {
  const requestId = crypto.randomUUID()
  const controller = new AbortController()
  const external = init.signal
  const abort = () => controller.abort()
  if (external?.aborted) controller.abort(external.reason)
  else external?.addEventListener('abort', abort, { once: true })
  const timeoutId = setTimeout(abort, timeoutMs)
  try {
    const response = await fetch(`${AUDIT_PATH}${path}`, {
      ...init,
      cache: 'no-store',
      credentials: 'include',
      signal: controller.signal,
      headers: {
        Accept: init.method === 'POST' ? 'application/pdf, application/json' : 'application/json',
        'X-Staff-Request': '1',
        'X-Correlation-ID': requestId,
        ...init.headers,
      },
    })
    if (controller.signal.aborted) {
      throw controller.signal.reason ?? new DOMException('Request aborted', 'AbortError')
    }
    const responseId = response.headers.get('X-Correlation-ID')
    const correlationId = responseId && SAFE_CORRELATION_ID.test(responseId) ? responseId : requestId
    if (!response.ok) {
      const problem = await readProblem(response, controller.signal)
      throw new AuditApiError(response.status, problem.code, correlationId, operation, problem.fields)
    }
    return await consume(response, correlationId, controller.signal)
  } catch (error) {
    if (error instanceof AuditApiError) throw error
    if (external?.aborted) throw error
    if (controller.signal.aborted) throw new AuditApiError(0, 'request_timeout', requestId, operation)
    throw new AuditApiError(0, 'network_error', requestId, operation)
  } finally {
    clearTimeout(timeoutId)
    external?.removeEventListener('abort', abort)
  }
}

async function getJson<T>(operation: AuditOperation, path: string, parse: (value: unknown) => T, signal?: AbortSignal): Promise<T> {
  return send(operation, path, { method: 'GET', signal }, REQUEST_TIMEOUT_MS, async (response, correlationId, requestSignal) => {
    let body: unknown
    try {
      body = await response.json()
    } catch (error) {
      if (requestSignal.aborted) throw error
      throw new AuditApiError(0, 'invalid_response', correlationId, operation)
    }
    try {
      return parse(body)
    } catch {
      throw new AuditApiError(0, 'invalid_response', correlationId, operation)
    }
  })
}

export function buildQuery(values: Record<string, string | number | undefined | null>): string {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null && value !== '') params.set(key, String(value))
  }
  const query = params.toString()
  return query ? `?${query}` : ''
}

export const auditApi = {
  catalog(signal?: AbortSignal): Promise<AuditCatalog> {
    return getJson('catalog', '/catalog', parseCatalog, signal)
  },

  events(
    period: AuditPeriodQuery,
    filters: AuditFilterQuery,
    page: { cursor?: string | null; limit?: number },
    signal?: AbortSignal,
  ): Promise<AuditEventPage> {
    const query = buildQuery({ ...period, ...filters, cursor: page.cursor, limit: page.limit })
    return getJson('events', `/events${query}`, parseEventPage, signal)
  },

  event(eventId: string, signal?: AbortSignal): Promise<AuditEvent> {
    if (!UUID_PATTERN.test(eventId)) return Promise.reject(new AuditApiError(404, 'audit_event_not_found', null, 'event'))
    return getJson('event', `/events/${encodeURIComponent(eventId)}`, parseAuditEvent, signal)
  },

  investigate(
    accountId: string,
    period: AuditPeriodQuery,
    page: { cursor?: string | null; limit?: number },
    signal?: AbortSignal,
  ): Promise<AuditInvestigationPage> {
    const query = buildQuery({ ...period, cursor: page.cursor, limit: page.limit })
    return getJson('investigation', `/investigations/${encodeURIComponent(accountId)}${query}`, parseInvestigationPage, signal)
  },

  summary(period: AuditPeriodQuery, filters: AuditFilterQuery, signal?: AbortSignal): Promise<AuditSummary> {
    return getJson('summary', `/summary${buildQuery({ ...period, ...filters })}`, parseSummary, signal)
  },

  report(period: AuditPeriodQuery, filters: AuditFilterQuery, signal?: AbortSignal): Promise<AuditReportFile> {
    const body: Record<string, string> = { ...period }
    for (const key of FILTER_KEYS) {
      const value = filters[key]
      if (value) body[key] = value
    }
    return send(
      'report',
      '/reports',
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal },
      REPORT_TIMEOUT_MS,
      async (response, correlationId, requestSignal) => {
        const reportId = response.headers.get('X-Report-Id') ?? ''
        const eventCount = Number(response.headers.get('X-Report-Event-Count'))
        const disposition = response.headers.get('Content-Disposition') ?? ''
        const filename = /filename="([^"]+)"/.exec(disposition)?.[1] ?? ''
        const contentType = response.headers.get('Content-Type') ?? ''
        if (
          !UUID_PATTERN.test(reportId) ||
          !isCount(eventCount) ||
          !REPORT_FILENAME.test(filename) ||
          !contentType.toLowerCase().startsWith('application/pdf')
        ) {
          throw new AuditApiError(0, 'invalid_response', correlationId, 'report')
        }
        try {
          const blob = await response.blob()
          if (requestSignal.aborted) {
            throw requestSignal.reason ?? new DOMException('Request aborted', 'AbortError')
          }
          return { blob, filename, reportId, eventCount }
        } catch (error) {
          if (requestSignal.aborted) throw error
          throw new AuditApiError(0, 'invalid_response', correlationId, 'report')
        }
      },
    )
  },
}
