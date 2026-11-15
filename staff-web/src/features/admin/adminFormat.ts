import type { AccountStatus } from './adminApi'

const ROLE_LABELS: Readonly<Record<string, string>> = {
  user: 'Cliente',
  support_agent: 'Agente de soporte',
  security_auditor: 'Auditor de seguridad',
  admin: 'Administrador',
}

const STATUS_LABELS: Readonly<Record<AccountStatus, string>> = {
  active: 'Activa',
  suspended: 'Suspendida',
}

const EVENT_LABELS: Readonly<Record<string, string>> = {
  ticket_created: 'Ticket creado',
  ticket_claimed: 'Reclamado por soporte',
  ticket_escalated: 'Escalado a administración',
  ticket_admin_claimed: 'Caso reclamado por un administrador',
  message_sent: 'Mensaje enviado',
  ticket_returned: 'Devuelto a soporte',
  ticket_resolved: 'Resuelto',
}

export function roleLabel(role: string): string {
  return ROLE_LABELS[role] ?? 'Rol desconocido'
}

export function statusLabel(status: AccountStatus): string {
  return STATUS_LABELS[status]
}

export function eventLabel(eventType: string): string {
  return EVENT_LABELS[eventType] ?? 'Actividad del caso'
}

export function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('es-CO', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
}

/** Digits only, at most JavaScript's safe integer range, never zero. */
export function parseAccountId(value: string): number | null {
  const trimmed = value.trim()
  if (!/^[1-9]\d{0,15}$/.test(trimmed)) return null
  const id = Number(trimmed)
  return Number.isSafeInteger(id) ? id : null
}

export function looksLikeEmail(value: string): boolean {
  const trimmed = value.trim()
  return trimmed.length >= 3 && trimmed.length <= 320 && /^[^@\s]+@[^@\s]+$/.test(trimmed)
}

/** The token travels in the URL fragment so it is never sent to a server or written to logs. */
export function activationLink(token: string): string {
  return `${window.location.origin}/activate#token=${token}`
}
