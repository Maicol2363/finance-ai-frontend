import { act, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from '../../app/router/AppRouter'
import { auditEvent, auditorSession, jsonResponse, period, problem, routeFetch } from '../../test/auditFixtures'

const metrics = [
  {
    key: 'successful_logins',
    label: 'Inicios de sesión exitosos',
    description: 'Inicios completados; auth.mfa_success no se cuenta.',
    mapping: [
      { event_type: 'auth.login_success', outcomes: ['success'] },
      { event_type: 'staff.login', outcomes: ['success'] },
    ],
    count: 3,
  },
  {
    key: 'failed_mfa',
    label: 'Verificaciones MFA fallidas',
    description: 'Medida del factor.',
    mapping: [{ event_type: 'auth.mfa_failed', outcomes: ['failure', 'denied'] }],
    count: 1,
  },
]

function summary(overrides: Record<string, unknown> = {}) {
  return {
    period,
    filters: {},
    cutoff: '2026-11-14T20:00:00Z',
    total_events: 4,
    metrics,
    by_type: [
      { event_type: 'auth.login_success', outcome: 'success', count: 2 },
      { event_type: 'staff.login', outcome: 'success', count: 1 },
      { event_type: 'auth.mfa_failed', outcome: 'failure', count: 1 },
    ],
    by_day: [
      { date: '2026-11-13', count: 0 },
      { date: '2026-11-14', count: 4 },
    ],
    earliest_recorded_at: '2026-10-01T00:00:00Z',
    coverage: 'available',
    ...overrides,
  }
}

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => { resolve = done })
  return { promise, resolve }
}

describe('Security Auditor investigation, summary and reports', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/')
    sessionStorage.clear()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('investigates a historical account oldest first with actor/target relations', async () => {
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/investigations/15') {
        return jsonResponse({
          account_id: '15',
          identity_lookup: 'not_performed',
          items: [
            { ...auditEvent({ actor_id: '15' }), match: 'actor' },
            {
              ...auditEvent({
                event_id: '44444444-4444-4444-8444-444444444444',
                actor_id: '1',
                target_type: 'account',
                target_id: '15',
                correlation_id: null,
              }),
              match: 'target',
            },
          ],
          next_cursor: null,
          read_boundary: '2026-11-14T20:00:00Z',
          period,
        })
      }
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/investigation?start_date=2026-11-01&end_date=2026-11-14')
    render(<AppRouter />)

    await user.type(await screen.findByLabelText('Identificador histórico de la cuenta'), 'abc')
    await user.click(screen.getByRole('button', { name: 'Investigar' }))
    expect(screen.getByText('Ingresa un identificador de cuenta numérico.')).toBeInTheDocument()

    await user.clear(screen.getByLabelText('Identificador histórico de la cuenta'))
    await user.type(screen.getByLabelText('Identificador histórico de la cuenta'), '15')
    await user.click(screen.getByRole('button', { name: 'Investigar' }))

    const table = await screen.findByRole('table')
    const rows = within(table).getAllByRole('row')
    expect(within(rows[1]).getByText('Actor')).toBeInTheDocument()
    expect(within(rows[2]).getByText('Cuenta afectada')).toBeInTheDocument()
    expect(screen.getByText(/no se lee el directorio/)).toBeInTheDocument()
    const call = fetchMock.mock.calls.find(([input]) => String(input).includes('/investigations/15'))
    expect(String(call?.[0])).toContain('start_date=2026-11-01')
  })

  it('pages an investigation and reports a failed page as an error', async () => {
    let failNext = false
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/investigations/15') {
        if (url.searchParams.get('cursor') === 'more') {
          return failNext
            ? problem('audit_query_unavailable', 503)
            : jsonResponse({
              account_id: '15',
              identity_lookup: 'not_performed',
              items: [{ ...auditEvent({ event_id: '66666666-6666-4666-8666-666666666666', actor_id: '15' }), match: 'actor_and_target' }],
              next_cursor: null,
              read_boundary: '2026-11-14T20:00:00Z',
              period,
            })
        }
        return jsonResponse({
          account_id: '15',
          identity_lookup: 'not_performed',
          items: [{ ...auditEvent({ actor_id: '15' }), match: 'actor' }],
          next_cursor: 'more',
          read_boundary: '2026-11-14T20:00:00Z',
          period,
        })
      }
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/investigation?account_id=15&start_date=2026-11-01&end_date=2026-11-14')
    const { unmount } = render(<AppRouter />)

    await user.click(await screen.findByRole('button', { name: 'Cargar eventos posteriores' }))
    expect(await screen.findByText('Actor y cuenta afectada')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Cargar eventos posteriores' })).not.toBeInTheDocument()
    unmount()

    failNext = true
    render(<AppRouter />)
    await user.click(await screen.findByRole('button', { name: 'Cargar eventos posteriores' }))
    expect(await screen.findByText(/Esto no significa que no haya actividad/)).toBeInTheDocument()
  })

  it('discards an in-flight investigation page when the account changes', async () => {
    const user = userEvent.setup()
    const nextPage = deferred<Response>()
    let nextSignal: AbortSignal | undefined
    routeFetch((url, init) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/investigations/15' && url.searchParams.get('cursor') === 'more') {
        nextSignal = init?.signal as AbortSignal | undefined
        return nextPage.promise
      }
      if (url.pathname === '/api/v1/staff/audit/investigations/15') {
        return jsonResponse({
          account_id: '15', identity_lookup: 'not_performed',
          items: [{ ...auditEvent(), match: 'actor' }], next_cursor: 'more',
          read_boundary: '2026-11-14T20:00:00Z', period,
        })
      }
      if (url.pathname === '/api/v1/staff/audit/investigations/16') {
        return jsonResponse({
          account_id: '16', identity_lookup: 'not_performed',
          items: [{ ...auditEvent({ event_type: 'staff.login', actor_id: '16' }), match: 'actor' }], next_cursor: null,
          read_boundary: '2026-11-14T20:00:00Z', period,
        })
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/investigation?account_id=15&start_date=2026-11-01&end_date=2026-11-14')
    render(<AppRouter />)

    await screen.findByRole('table')
    await user.click(screen.getByRole('button', { name: 'Cargar eventos posteriores' }))
    await waitFor(() => expect(nextSignal).toBeDefined())
    await user.clear(screen.getByLabelText('Identificador histórico de la cuenta'))
    await user.type(screen.getByLabelText('Identificador histórico de la cuenta'), '16')
    await user.click(screen.getByRole('button', { name: 'Investigar' }))

    expect(await screen.findByText('Cuenta 16: 1 eventos, de más antiguo a más reciente, en America/Bogota (UTC−05:00).')).toBeInTheDocument()
    expect(nextSignal?.aborted).toBe(true)
    nextPage.resolve(jsonResponse({
      account_id: '15', identity_lookup: 'not_performed',
      items: [{ ...auditEvent({ event_type: 'auth.mfa_failed', actor_id: '15' }), match: 'actor' }],
      next_cursor: null, read_boundary: '2026-11-14T20:00:00Z', period,
    }))
    await waitFor(() => expect(within(screen.getByRole('table')).queryByText('auth.mfa_failed')).not.toBeInTheDocument())
    expect(within(screen.getByRole('table')).getByText('staff.login')).toBeInTheDocument()
  })

  it('shows an empty investigation without inventing history', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/investigations/999') {
        return jsonResponse({
          account_id: '999',
          identity_lookup: 'not_performed',
          items: [],
          next_cursor: null,
          read_boundary: '2026-11-14T20:00:00Z',
          period,
        })
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/investigation?account_id=999')
    render(<AppRouter />)
    expect(await screen.findByTestId('audit-investigation-empty')).toHaveTextContent('Sin eventos registrados para la cuenta 999')
  })

  it('shows complete-dataset metrics, coverage, cutoff and links to the matching list', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/summary') return jsonResponse(summary({ coverage: 'partial' }))
      return undefined
    })
    window.history.pushState({}, '', '/audit/summary?start_date=2026-11-01&end_date=2026-11-14&actor_id=9')
    render(<AppRouter />)

    expect(await screen.findByTestId('audit-summary-total')).toHaveTextContent('4')
    expect(screen.getByTestId('audit-metric-successful_logins')).toHaveTextContent('3')
    expect(screen.getByText(/Resumen calculado al corte/)).toBeInTheDocument()
    expect(screen.getByText(/no tienen cobertura/)).toBeInTheDocument()
    const chip = screen.getByRole('link', { name: /auth\.login_success · Éxito: 2/ })
    const href = new URL(chip.getAttribute('href') ?? '', 'http://x')
    expect(href.pathname).toBe('/audit/events')
    expect(href.searchParams.get('event_type')).toBe('auth.login_success')
    expect(href.searchParams.get('outcome')).toBe('success')
    expect(href.searchParams.get('actor_id')).toBe('9')
    expect(href.searchParams.get('start_date')).toBe('2026-11-01')
    expect(screen.getByTestId('audit-distribution-chart')).toHaveTextContent('auth.mfa_failed · Fallo')
    expect(screen.getByTestId('audit-timeline-chart')).toBeInTheDocument()
    expect(screen.getByRole('table', { name: 'Eventos por día' })).toBeInTheDocument()
  })

  it('marks mapping entries outside an active type filter instead of linking them', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/summary') return jsonResponse(summary())
      return undefined
    })
    window.history.pushState({}, '', '/audit/summary?start_date=2026-11-01&end_date=2026-11-14&event_type=staff.login')
    render(<AppRouter />)
    await screen.findByTestId('audit-summary')
    expect(screen.getAllByText(/fuera del filtro aplicado/).length).toBeGreaterThan(0)
    expect(screen.getByRole('link', { name: /staff\.login · Éxito: 1/ })).toBeInTheDocument()
  })

  it('distinguishes zero activity from an empty store', async () => {
    let coverage = 'no_records'
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/summary') {
        return jsonResponse(summary({
          total_events: 0,
          metrics: metrics.map((metric) => ({ ...metric, count: 0 })),
          by_type: [],
          by_day: [{ date: '2026-11-14', count: 0 }],
          earliest_recorded_at: coverage === 'no_records' ? null : '2026-10-01T00:00:00Z',
          coverage,
        }))
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/summary')
    const { unmount } = render(<AppRouter />)
    expect(await screen.findByText(/no tiene eventos registrados/)).toBeInTheDocument()
    expect(screen.queryByTestId('audit-distribution-chart')).not.toBeInTheDocument()
    unmount()

    coverage = 'available'
    render(<AppRouter />)
    expect(await screen.findByText('No se registraron eventos en este periodo con los filtros aplicados.')).toBeInTheDocument()
  })

  it('downloads a generated PDF and shows its report id and count', async () => {
    const createObjectURL = vi.fn(() => 'blob:report')
    const revokeObjectURL = vi.fn()
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL, revokeObjectURL }))
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => undefined)
    const reportId = '55555555-5555-4555-8555-555555555555'
    const fetchMock = routeFetch((url, init) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/reports' && init?.method === 'POST') {
        return new Response('%PDF-1.4', {
          status: 200,
          headers: {
            'Content-Type': 'application/pdf',
            'Content-Disposition': `attachment; filename="informe-auditoria-${reportId}.pdf"`,
            'X-Report-Id': reportId,
            'X-Report-Event-Count': '12',
          },
        })
      }
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/reports')
    render(<AppRouter />)

    await user.selectOptions(await screen.findByLabelText('Resultado'), 'denied')
    await user.click(screen.getByRole('button', { name: 'Generar informe PDF' }))

    const ready = await screen.findByTestId('audit-report-ready')
    expect(ready).toHaveTextContent(reportId)
    expect(ready).toHaveTextContent('12')
    expect(click).toHaveBeenCalledOnce()
    expect(createObjectURL).toHaveBeenCalledOnce()
    const call = fetchMock.mock.calls.find(([input]) => String(input).endsWith('/reports'))
    const body = JSON.parse(String(call?.[1]?.body)) as Record<string, string>
    expect(body.outcome).toBe('denied')
    expect(body.time_zone).toBe('America/Bogota')
    expect(new Headers(call?.[1]?.headers).get('X-Staff-Request')).toBe('1')
  })

  it('aborts report generation and avoids download side effects after unmount', async () => {
    const pendingResponse = deferred<Response>()
    const createObjectURL = vi.fn(() => 'blob:late-report')
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL, revokeObjectURL: vi.fn() }))
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => undefined)
    let requestSignal: AbortSignal | undefined
    const fetchMock = routeFetch((url, init) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/reports' && init?.method === 'POST') {
        requestSignal = init.signal as AbortSignal | undefined
        return pendingResponse.promise
      }
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/reports')
    const { unmount } = render(<AppRouter />)
    await user.click(await screen.findByRole('button', { name: 'Generar informe PDF' }))
    await waitFor(() => expect(requestSignal).toBeDefined())

    unmount()
    expect(requestSignal?.aborted).toBe(true)
    const reportId = '55555555-5555-4555-8555-555555555555'
    await act(async () => {
      pendingResponse.resolve(new Response('%PDF-1.4', {
        status: 200,
        headers: {
          'Content-Type': 'application/pdf',
          'Content-Disposition': `attachment; filename="informe-auditoria-${reportId}.pdf"`,
          'X-Report-Id': reportId,
          'X-Report-Event-Count': '12',
        },
      }))
      await new Promise((resolve) => setTimeout(resolve, 0))
    })
    expect(fetchMock).toHaveBeenCalled()
    expect(createObjectURL).not.toHaveBeenCalled()
    expect(click).not.toHaveBeenCalled()
  })

  it.each([
    ['audit_report_too_large', 422, /máximo de 2000 eventos por informe/],
    ['audit_export_unrecorded', 503, /no fue posible registrar su exportación/],
    ['audit_report_generation_failed', 500, /no se produjo ningún archivo/],
  ])('reports %s without producing a download', async (code, status, message) => {
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => undefined)
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/reports') return problem(code, status)
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/reports')
    render(<AppRouter />)
    await user.click(await screen.findByRole('button', { name: 'Generar informe PDF' }))
    expect(await screen.findByText(message)).toBeInTheDocument()
    expect(screen.queryByTestId('audit-report-ready')).not.toBeInTheDocument()
    expect(click).not.toHaveBeenCalled()
  })

  it('rejects a report response without trusted metadata', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/reports') {
        return new Response(new Blob(['<html>']), { status: 200, headers: { 'Content-Type': 'text/html' } })
      }
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/reports')
    render(<AppRouter />)
    await user.click(await screen.findByRole('button', { name: 'Generar informe PDF' }))
    await waitFor(() => expect(screen.getByTestId('audit-error')).toBeInTheDocument())
    expect(screen.queryByTestId('audit-report-ready')).not.toBeInTheDocument()
  })
})
