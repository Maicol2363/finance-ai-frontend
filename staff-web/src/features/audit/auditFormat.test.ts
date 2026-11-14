import { afterEach, describe, expect, it, vi } from 'vitest'
import { AuditApiError, auditApi, buildQuery, parseEventPage, parseSummary } from './auditApi'
import {
  defaultPeriod,
  formatInstant,
  needsSessionCheck,
  periodDays,
  readQuery,
  safeAuditDiagnostic,
  safeAuditMessage,
  shiftDate,
  targetLabel,
  todayInZone,
  toSearchParams,
  validateFilters,
  validatePeriod,
  zoneLabel,
} from './auditFormat'

const limits = { maxDays: 90, maxReportEvents: 2000 }

describe('audit date handling', () => {
  it('derives the Bogota calendar day from UTC and builds a seven-day default period', () => {
    const lateEvening = new Date('2026-11-15T03:30:00Z') // 22:30 on Nov 14 in Bogota
    expect(todayInZone('America/Bogota', lateEvening)).toBe('2026-11-14')
    expect(todayInZone('UTC', lateEvening)).toBe('2026-11-15')
    expect(defaultPeriod('America/Bogota', lateEvening)).toEqual({
      start_date: '2026-11-08',
      end_date: '2026-11-14',
      time_zone: 'America/Bogota',
    })
    expect(shiftDate('2026-03-01', -1)).toBe('2026-02-28')
    expect(periodDays('2026-01-01', '2026-03-31')).toBe(90)
  })

  it('labels the presentation zone explicitly', () => {
    expect(zoneLabel('America/Bogota')).toContain('UTC−05:00')
    expect(zoneLabel('Mars/Base')).toBe('Mars/Base')
    expect(formatInstant('2026-11-15T03:30:00Z', 'America/Bogota')).toContain('22:30:00')
    expect(formatInstant('2026-11-15T03:30:00Z', 'UTC')).toContain('03:30:00')
  })

  it('validates period order, size and format before any request', () => {
    expect(validatePeriod({ start_date: '2026-01-01', end_date: '2026-03-31', time_zone: 'UTC' }, 90)).toEqual({})
    expect(validatePeriod({ start_date: '2026-01-01', end_date: '2026-04-01', time_zone: 'UTC' }, 90).end_date).toMatch(/90 días/)
    expect(validatePeriod({ start_date: '2026-02-01', end_date: '2026-01-01', time_zone: 'UTC' }, 90).end_date).toMatch(/posterior/)
    const malformed = validatePeriod({ start_date: 'ayer', end_date: '', time_zone: 'UTC' }, 90)
    expect(malformed.start_date).toBeDefined()
    expect(malformed.end_date).toBeDefined()
  })

  it('validates identifier namespaces and patterns', () => {
    expect(validateFilters({ actor_id: '15', event_type: 'auth.mfa_failed', correlation_id: 'abc-1' })).toEqual({})
    const errors = validateFilters({
      actor_id: '0x1',
      event_type: 'DROP TABLE',
      target_id: '15',
      correlation_id: 'a b',
    })
    expect(Object.keys(errors).sort()).toEqual(['actor_id', 'correlation_id', 'event_type', 'target_type'])
    expect(validateFilters({ target_type: 'account', target_id: 'bad id' }).target_id).toBeDefined()
  })

  it('round-trips query parameters and ignores unsupported zones', () => {
    const params = toSearchParams(
      { start_date: '2026-11-01', end_date: '2026-11-02', time_zone: 'UTC' },
      { outcome: 'denied', actor_id: '9' },
      { account_id: '9' },
    )
    expect(params.get('account_id')).toBe('9')
    const parsed = readQuery(params)
    expect(parsed.period).toEqual({ start_date: '2026-11-01', end_date: '2026-11-02', time_zone: 'UTC' })
    expect(parsed.filters).toEqual({ outcome: 'denied', actor_id: '9' })
    expect(readQuery(new URLSearchParams('time_zone=Europe/Madrid')).period.time_zone).toBe('America/Bogota')
    expect(buildQuery({ a: '1', b: undefined, c: '', d: 0 })).toBe('?a=1&d=0')
    expect(buildQuery({})).toBe('')
  })

  it('describes targets and unknown values without inventing identities', () => {
    expect(targetLabel(null, null)).toBe('No registrado')
    expect(targetLabel('account', '15')).toBe('Cuenta · 15')
    expect(targetLabel('custom_type', null)).toBe('custom_type')
    expect(targetLabel(null, '7')).toBe('Tipo no registrado · 7')
  })
})

describe('audit error handling', () => {
  afterEach(() => vi.unstubAllGlobals())

  it.each([
    ['audit_query_invalid', ['end_date', 'secret_field'], /fecha final/],
    ['audit_query_invalid', [], /Revisa los filtros/],
    ['request_invalid', [], /formato no válido/],
    ['audit_rate_limited', [], /Demasiadas solicitudes/],
    ['session_invalid', [], /La estamos renovando/],
    ['network_error', [], /No se pudo conectar/],
    ['internal_error', [], /No se pudo completar/],
  ])('maps %s to a safe message', (code, fields, message) => {
    const error = new AuditApiError(422, code, 'corr-1', 'events', fields)
    expect(safeAuditMessage(error, limits)).toMatch(message)
    expect(error.fields).not.toContain('secret_field')
  })

  it('never trusts unknown codes or unsafe correlation identifiers', () => {
    const error = new AuditApiError(500, '<script>', 'bad id with spaces', 'summary')
    expect(error.code).toBe('unknown_error')
    expect(error.correlationId).toBeNull()
    expect(safeAuditMessage(new Error('raw'), limits)).toMatch(/No se pudo completar/)
    expect(safeAuditDiagnostic(new Error('raw'), 'report')).toMatchObject({ code: 'unclassified_error', operation: 'report' })
    expect(needsSessionCheck(new AuditApiError(403, 'staff_access_denied', null, 'events'))).toBe(true)
    expect(needsSessionCheck(new AuditApiError(422, 'request_invalid', null, 'events'))).toBe(false)
  })

  it('rejects malformed server payloads instead of rendering them', () => {
    expect(() => parseEventPage({ items: [{ event_id: 'not-a-uuid' }], next_cursor: null })).toThrow()
    expect(() => parseSummary({ coverage: 'complete' })).toThrow()
  })

  it('turns transport failures and malformed JSON into safe errors', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new TypeError('network down')
    }))
    await expect(auditApi.catalog()).rejects.toMatchObject({ code: 'network_error', operation: 'catalog' })
    vi.stubGlobal('fetch', vi.fn(async () => new Response('not json', { status: 200 })))
    await expect(auditApi.catalog()).rejects.toMatchObject({ code: 'invalid_response' })
    vi.stubGlobal('fetch', vi.fn(async () => new Response('oops', { status: 500 })))
    await expect(auditApi.summary({ start_date: '2026-11-01', end_date: '2026-11-02', time_zone: 'UTC' }, {})).rejects.toMatchObject({
      code: 'unknown_error',
      status: 500,
    })
    await expect(auditApi.event('../../admin')).rejects.toMatchObject({ code: 'audit_event_not_found' })
  })
})
