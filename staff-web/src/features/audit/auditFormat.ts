import {
  AuditApiError,
  FILTER_KEYS,
  type AuditFilterQuery,
  type AuditMatch,
  type AuditOperation,
  type AuditPeriodQuery,
  type AuditTimeZone,
} from './auditApi'

export const DEFAULT_TIME_ZONE: AuditTimeZone = 'America/Bogota'
export const DEFAULT_MAX_QUERY_DAYS = 90
export const DEFAULT_MAX_REPORT_EVENTS = 2_000
const DAY_MS = 86_400_000

export const ZONE_LABELS: Readonly<Record<AuditTimeZone, string>> = {
  'America/Bogota': 'America/Bogota (UTC−05:00)',
  UTC: 'UTC (UTC+00:00)',
}

export const OUTCOME_LABELS: Readonly<Record<string, string>> = {
  success: 'Éxito',
  denied: 'Denegado',
  failure: 'Fallo',
}

export const TARGET_TYPE_LABELS: Readonly<Record<string, string>> = {
  account: 'Cuenta',
  audit_report: 'Informe de auditoría',
  protected_resource: 'Recurso protegido',
  staff_invitation: 'Invitación del personal',
  staff_session: 'Sesión del personal',
  support_ticket: 'Ticket de soporte',
}

/** The four fixed roles, as recorded on each event at the time it happened. */
export const ROLE_LABELS: Readonly<Record<string, string>> = {
  user: 'Usuario (cliente)',
  support_agent: 'Agente de soporte',
  admin: 'Administrador',
  security_auditor: 'Auditor de seguridad',
}

/** Readable names; the exact event code is always shown next to them. */
export const EVENT_TYPE_LABELS: Readonly<Record<string, string>> = {
  'access.denied': 'Acceso denegado',
  'account.reactivated': 'Cuenta reactivada',
  'account.suspended': 'Cuenta suspendida',
  'audit.report_exported': 'Informe de auditoría exportado',
  'auth.login_failed': 'Inicio de sesión fallido',
  'auth.login_success': 'Inicio de sesión exitoso',
  'auth.logout': 'Cierre de sesión',
  'auth.mfa_enrolled': 'Autenticador configurado',
  'auth.mfa_failed': 'Verificación en dos pasos fallida',
  'auth.mfa_recovered': 'Acceso recuperado con código de recuperación',
  'auth.mfa_replaced': 'Autenticador reemplazado',
  'auth.mfa_success': 'Verificación en dos pasos correcta',
  'role.changed': 'Cambio de rol',
  'session.revoked': 'Sesión revocada',
  'staff.activated': 'Cuenta del personal activada',
  'staff.created': 'Invitación al personal creada',
  'staff.login': 'Inicio de sesión del personal',
  'staff.login_denied': 'Inicio de sesión del personal rechazado',
  'staff.logout': 'Cierre de sesión del personal',
  'staff.refresh': 'Sesión del personal renovada',
  'staff.session_revoked': 'Sesión del personal revocada',
  'support.customer_lookup': 'Consulta de cliente por soporte',
  'support.message_sent': 'Mensaje de soporte enviado',
  'support.ticket_claimed': 'Ticket tomado por soporte',
  'support.ticket_created': 'Ticket creado',
  'support.ticket_resolved': 'Ticket resuelto',
  'support.ticket_returned': 'Ticket devuelto a soporte',
  'ticket.escalated': 'Ticket escalado',
}

const CONTEXT_KEY_LABELS: Readonly<Record<string, string>> = {
  reason: 'Motivo',
  resource: 'Recurso',
  channel: 'Origen',
  platform: 'Plataforma',
  previous_role: 'Rol anterior',
  new_role: 'Rol nuevo',
  report_id: 'Id. del informe',
  period_start: 'Inicio del periodo',
  period_end: 'Fin del periodo',
  time_zone: 'Zona horaria',
  event_count: 'Eventos incluidos',
  filter_event_type: 'Filtro: tipo de evento',
  filter_outcome: 'Filtro: resultado',
  filter_actor_id: 'Filtro: actor',
  filter_actor_role: 'Filtro: rol del actor',
  filter_target_type: 'Filtro: tipo de objetivo',
  filter_target_id: 'Filtro: objetivo',
  filter_correlation_id: 'Filtro: correlación',
}

const CONTEXT_VALUE_LABELS: Readonly<Record<string, string>> = {
  customer_app: 'App de clientes',
  android: 'Android',
  windows: 'Windows',
  invalid_credentials: 'Credenciales incorrectas',
  account_inactive: 'Cuenta inactiva',
  role_not_permitted: 'Rol sin permiso',
  invalid_code: 'Código incorrecto',
  ineligible: 'Cuenta no habilitada',
}

/** Short help shown under each field while it has focus. */
export const FIELD_HINTS = {
  start_date: 'Primer día incluido en la búsqueda, en la zona horaria elegida.',
  end_date: 'Último día incluido completo, hasta las 23:59:59.',
  time_zone: 'Define cómo se muestran las horas y dónde empieza cada día. Los eventos se guardan en UTC.',
  event_type: 'La acción registrada, por ejemplo un inicio de sesión fallido o un acceso denegado.',
  outcome:
    'Éxito: la acción se completó. Denegado: se bloqueó por permisos o por el estado de la cuenta. Fallo: no se completó por un dato incorrecto o un error.',
  actor_role:
    'Rol que tenía quien hizo la acción en el momento del evento. Los eventos sin rol registrado no aparecen al usar este filtro.',
  actor_id: 'Número de la cuenta que hizo la acción. Lo ves en la columna Actor o en el detalle de un evento.',
  target_type: 'Clase de elemento afectado por la acción: una cuenta, una sesión, un ticket, un informe…',
  target_id: 'Identificador del elemento afectado. Elige antes el tipo de objetivo.',
  correlation_id:
    'Código que comparten todos los eventos de una misma solicitud u operación. Sirve para ver juntos los pasos de, por ejemplo, un mismo inicio de sesión.',
  account_id: 'Número de la cuenta a investigar. Se buscan los eventos donde actuó o donde fue afectada.',
} as const

/** Ids of a field's help text and, when present, its error, for the control's aria-describedby. */
export function describedBy(id: string, error?: string): string {
  return error ? `${id}-hint ${id}-error` : `${id}-hint`
}

export const PERIOD_PRESETS: ReadonlyArray<{ days: number; label: string }> = [
  { days: 1, label: 'Hoy' },
  { days: 7, label: 'Últimos 7 días' },
  { days: 30, label: 'Últimos 30 días' },
  { days: 90, label: 'Últimos 90 días' },
]

export const MATCH_LABELS: Readonly<Record<AuditMatch, string>> = {
  actor: 'Actor',
  target: 'Cuenta afectada',
  actor_and_target: 'Actor y cuenta afectada',
}

export const FIELD_LABELS: Readonly<Record<string, string>> = {
  start_date: 'fecha inicial',
  end_date: 'fecha final',
  time_zone: 'zona horaria',
  event_type: 'tipo de evento',
  outcome: 'resultado',
  actor_id: 'actor',
  actor_role: 'rol del actor',
  target_type: 'tipo de objetivo',
  target_id: 'objetivo',
  correlation_id: 'correlación',
  cursor: 'posición de la página',
  limit: 'tamaño de página',
  account_id: 'identificador de cuenta',
}

export const UNKNOWN_VALUE = 'No registrado'

export function isTimeZone(value: unknown): value is AuditTimeZone {
  return value === 'America/Bogota' || value === 'UTC'
}

/** Calendar date (YYYY-MM-DD) of "now" in the reporting zone. */
export function todayInZone(zone: AuditTimeZone, now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now)
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? ''
  return `${part('year')}-${part('month')}-${part('day')}`
}

export function shiftDate(isoDate: string, days: number): string {
  const time = Date.parse(`${isoDate}T00:00:00Z`)
  return new Date(time + days * DAY_MS).toISOString().slice(0, 10)
}

/** Inclusive number of calendar days between two YYYY-MM-DD dates. */
export function periodDays(start: string, end: string): number {
  return Math.round((Date.parse(`${end}T00:00:00Z`) - Date.parse(`${start}T00:00:00Z`)) / DAY_MS) + 1
}

export function defaultPeriod(zone: AuditTimeZone = DEFAULT_TIME_ZONE, now = new Date()): AuditPeriodQuery {
  return presetPeriod(7, zone, now)
}

/** The last `days` calendar days ending today in the reporting zone (1 = today only). */
export function presetPeriod(days: number, zone: AuditTimeZone = DEFAULT_TIME_ZONE, now = new Date()): AuditPeriodQuery {
  const end = todayInZone(zone, now)
  return { start_date: shiftDate(end, -(days - 1)), end_date: end, time_zone: zone }
}

/** Whether the period still grows: events recorded from now on can fall inside it. */
export function periodIncludesToday(period: AuditPeriodQuery, now = new Date()): boolean {
  return period.end_date >= todayInZone(period.time_zone, now)
}

export function formatInstant(iso: string, zone: string): string {
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(new Date(iso))
}

export function zoneLabel(zone: string): string {
  return isTimeZone(zone) ? ZONE_LABELS[zone] : zone
}

export function outcomeLabel(outcome: string): string {
  return OUTCOME_LABELS[outcome] ?? outcome
}

export function roleLabel(role: string | null): string {
  if (!role) return UNKNOWN_VALUE
  return ROLE_LABELS[role] ?? role
}

export function eventTypeLabel(eventType: string): string {
  return EVENT_TYPE_LABELS[eventType] ?? eventType
}

export function contextKeyLabel(key: string): string {
  return CONTEXT_KEY_LABELS[key] ?? key
}

/** A readable value for known codes and roles; anything else is shown exactly as recorded. */
export function contextValueLabel(key: string, value: string): string {
  if (key === 'previous_role' || key === 'new_role' || key === 'filter_actor_role') return ROLE_LABELS[value] ?? value
  return CONTEXT_VALUE_LABELS[value] ?? value
}

/** Where a sign-in came from, e.g. "App de clientes · Android"; null when not recorded. */
export function originLabel(context: Record<string, string>): string | null {
  if (!context.channel) return null
  const channel = contextValueLabel('channel', context.channel)
  return context.platform ? `${channel} · ${contextValueLabel('platform', context.platform)}` : channel
}

export function targetLabel(type: string | null, id: string | null): string {
  if (!type && !id) return UNKNOWN_VALUE
  const typeLabel = type ? (TARGET_TYPE_LABELS[type] ?? type) : 'Tipo no registrado'
  return id ? `${typeLabel} · ${id}` : typeLabel
}

const VALID_DATE = /^\d{4}-\d{2}-\d{2}$/
const EVENT_TYPE = /^[a-z][a-z0-9_]{0,39}(\.[a-z0-9_]{1,40}){1,3}$/
const ACTOR_ID = /^[1-9]\d{0,18}$/
const TARGET_ID = /^[A-Za-z0-9._:-]{1,128}$/
const CORRELATION_ID = /^[A-Za-z0-9._-]{1,64}$/

/** Client-side guidance only; the backend validates and authorizes every request. */
export function validatePeriod(period: AuditPeriodQuery, maxDays: number): Record<string, string> {
  const errors: Record<string, string> = {}
  if (!VALID_DATE.test(period.start_date) || !Number.isFinite(Date.parse(period.start_date))) {
    errors.start_date = 'Ingresa una fecha inicial válida.'
  }
  if (!VALID_DATE.test(period.end_date) || !Number.isFinite(Date.parse(period.end_date))) {
    errors.end_date = 'Ingresa una fecha final válida.'
  }
  if (!errors.start_date && !errors.end_date) {
    if (period.end_date < period.start_date) {
      errors.end_date = 'La fecha final debe ser igual o posterior a la inicial.'
    } else if (periodDays(period.start_date, period.end_date) > maxDays) {
      errors.end_date = `El periodo no puede superar ${maxDays} días.`
    }
  }
  return errors
}

export function validateFilters(filters: AuditFilterQuery): Record<string, string> {
  const errors: Record<string, string> = {}
  if (filters.event_type && !EVENT_TYPE.test(filters.event_type)) errors.event_type = 'Selecciona un tipo de evento válido.'
  if (filters.actor_id && !ACTOR_ID.test(filters.actor_id)) errors.actor_id = 'El actor es un identificador numérico de cuenta.'
  if (filters.actor_role && !(filters.actor_role in ROLE_LABELS)) errors.actor_role = 'Selecciona uno de los cuatro roles.'
  if (filters.target_id && !TARGET_ID.test(filters.target_id)) errors.target_id = 'El objetivo contiene caracteres no permitidos.'
  if (filters.target_id && !filters.target_type) errors.target_type = 'Selecciona el tipo de objetivo para este identificador.'
  if (filters.correlation_id && !CORRELATION_ID.test(filters.correlation_id)) {
    errors.correlation_id = 'La correlación solo admite letras, números, punto, guion y guion bajo.'
  }
  return errors
}

export function isAccountId(value: string): boolean {
  return ACTOR_ID.test(value)
}

/** Reads the period and filters from URL search parameters, falling back to safe defaults. */
export function readQuery(params: URLSearchParams): { period: AuditPeriodQuery; filters: AuditFilterQuery } {
  const zoneParam = params.get('time_zone')
  const zone = isTimeZone(zoneParam) ? zoneParam : DEFAULT_TIME_ZONE
  const fallback = defaultPeriod(zone)
  const period: AuditPeriodQuery = {
    start_date: params.get('start_date') ?? fallback.start_date,
    end_date: params.get('end_date') ?? fallback.end_date,
    time_zone: zone,
  }
  const filters: AuditFilterQuery = {}
  for (const key of FILTER_KEYS) {
    const value = params.get(key)?.trim()
    if (value) filters[key] = value
  }
  return { period, filters }
}

export function toSearchParams(period: AuditPeriodQuery, filters: AuditFilterQuery, extra: Record<string, string> = {}): URLSearchParams {
  const params = new URLSearchParams({ ...extra, ...period })
  for (const key of FILTER_KEYS) {
    const value = filters[key]
    if (value) params.set(key, value)
  }
  return params
}

export function safeAuditMessage(error: unknown, limits: { maxDays: number; maxReportEvents: number }): string {
  if (!(error instanceof AuditApiError)) return 'No se pudo completar la solicitud. Inténtalo de nuevo.'
  switch (error.code) {
    case 'audit_query_invalid': {
      const fields = error.fields.map((field) => FIELD_LABELS[field] ?? field)
      return fields.length
        ? `Revisa estos datos: ${fields.join(', ')}.`
        : 'Revisa los filtros e inténtalo de nuevo.'
    }
    case 'request_invalid':
      return 'Algún filtro tiene un formato no válido. Revísalo e inténtalo de nuevo.'
    case 'audit_period_too_long':
      return `El periodo supera el máximo permitido de ${limits.maxDays} días. Acórtalo e inténtalo de nuevo.`
    case 'audit_event_not_found':
      return 'El evento solicitado no existe o no está disponible.'
    case 'audit_report_too_large':
      return `La selección supera el máximo de ${limits.maxReportEvents} eventos por informe. Acota el periodo o agrega filtros; el informe nunca se recorta.`
    case 'audit_report_generation_failed':
      return 'No se pudo generar el informe y no se produjo ningún archivo. Inténtalo de nuevo.'
    case 'audit_export_unrecorded':
      return 'El informe no se entregó porque no fue posible registrar su exportación. Inténtalo más tarde.'
    case 'audit_query_unavailable':
      return 'No se pudieron consultar los eventos. Esto no significa que no haya actividad; inténtalo de nuevo.'
    case 'audit_rate_limited':
      return 'Demasiadas solicitudes. Espera un minuto e inténtalo de nuevo.'
    case 'staff_access_denied':
      return 'Tu acceso de auditor ya no está disponible. Vuelve a iniciar sesión si aún tienes autorización.'
    case 'access_expired':
    case 'authentication_required':
    case 'session_invalid':
      return 'Tu sesión necesita confirmarse. La estamos renovando; vuelve a intentarlo en un momento.'
    case 'network_error':
    case 'request_timeout':
      return 'No se pudo conectar con el servicio. Comprueba tu conexión e inténtalo de nuevo.'
    default:
      return 'No se pudo completar la solicitud. Inténtalo de nuevo.'
  }
}

/** Errors after which the current session must be re-confirmed by the coordinator. */
export function needsSessionCheck(error: unknown): boolean {
  return error instanceof AuditApiError && (error.status === 401 || error.status === 403)
}

export interface AuditDiagnostic {
  code: string
  operation: AuditOperation
  occurredAtUtc: string
  correlationId: string | null
}

export function safeAuditDiagnostic(error: unknown, operation: AuditOperation): AuditDiagnostic {
  const apiError = error instanceof AuditApiError ? error : null
  return {
    code: apiError?.code ?? 'unclassified_error',
    operation: apiError?.operation ?? operation,
    occurredAtUtc: new Date().toISOString(),
    correlationId: apiError?.correlationId ?? null,
  }
}
