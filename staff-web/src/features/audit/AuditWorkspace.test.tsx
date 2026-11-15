import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from '../../app/router/AppRouter'
import {
  auditEvent,
  auditorSession,
  jsonResponse,
  period,
  problem,
  requestedPaths,
  routeFetch,
  supportSession,
} from '../../test/auditFixtures'

function eventsPage(items: unknown[], nextCursor: string | null = null) {
  return { items, next_cursor: nextCursor, read_boundary: '2026-11-14T20:00:00Z', period, filters: {} }
}

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => { resolve = done })
  return { promise, resolve }
}

describe('Security Auditor workspace', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/')
    sessionStorage.clear()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('routes an auditor to the audit workspace and lists sanitized events newest first', async () => {
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') {
        return jsonResponse(eventsPage([
          auditEvent(),
          auditEvent({
            event_id: '22222222-2222-4222-8222-222222222222',
            actor_id: null,
            correlation_id: null,
            target_type: null,
            target_id: null,
            event_type: 'staff.login_denied',
          }),
        ]))
      }
      return undefined
    })
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Auditoría de seguridad' })).toBeInTheDocument()
    const table = await screen.findByRole('table')
    const rows = within(table).getAllByRole('row')
    expect(rows).toHaveLength(3)
    expect(within(rows[2]).getAllByText('No registrado')).toHaveLength(3)
    expect(within(rows[2]).getByText('No registrado', { selector: 'td' })).toBeInTheDocument()
    expect(screen.getByText(/Fecha y hora · America\/Bogota/)).toBeInTheDocument()
    const eventsCall = fetchMock.mock.calls.find(([input]) => String(input).startsWith('/api/v1/staff/audit/events'))
    expect(eventsCall?.[1]?.credentials).toBe('include')
    expect(new Headers(eventsCall?.[1]?.headers).get('X-Staff-Request')).toBe('1')
    expect(requestedPaths(fetchMock).some((path) => path.includes('/staff/support/'))).toBe(false)
  })

  it('keeps section navigation rooted at the audit workspace from nested pages', async () => {
    const user = userEvent.setup()
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') return jsonResponse(eventsPage([auditEvent()]))
      if (url.pathname === '/api/v1/staff/audit/summary') {
        return jsonResponse({
          period,
          filters: {},
          cutoff: '2026-11-14T20:00:00Z',
          total_events: 1,
          metrics: [],
          by_type: [{ event_type: 'access.denied', outcome: 'denied', count: 1 }],
          by_day: [{ date: '2026-11-14', count: 1 }],
          earliest_recorded_at: '2026-11-01T00:00:00Z',
          coverage: 'available',
        })
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/summary')
    render(<AppRouter />)

    expect(await screen.findByTestId('audit-summary')).toBeInTheDocument()
    await user.click(screen.getByRole('link', { name: 'Eventos' }))
    expect(await screen.findByRole('heading', { name: 'Eventos de seguridad' })).toBeInTheDocument()
    expect(window.location.pathname).toBe('/audit/events')
  })

  it('denies the audit workspace to a support agent without requesting audit data', async () => {
    const fetchMock = routeFetch((url) => (url.pathname.endsWith('/staff/auth/session') ? jsonResponse(supportSession) : undefined))
    window.history.pushState({}, '', '/audit/events')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Esta sección no corresponde a tu rol' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Ir a mi espacio' })).toHaveAttribute('href', '/support')
    expect(requestedPaths(fetchMock).some((path) => path.includes('/staff/audit/'))).toBe(false)
  })

  it('applies combined filters through the URL and pages with the server cursor', async () => {
    const user = userEvent.setup()
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') {
        if (url.searchParams.get('cursor') === 'next-page') {
          return jsonResponse(eventsPage([auditEvent({ event_id: '33333333-3333-4333-8333-333333333333' })]))
        }
        return jsonResponse(eventsPage([auditEvent()], 'next-page'))
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-11-01&end_date=2026-11-14&time_zone=America%2FBogota')
    render(<AppRouter />)

    await screen.findByRole('table')
    await user.selectOptions(screen.getByLabelText('Tipo de evento'), 'access.denied')
    await user.selectOptions(screen.getByLabelText('Resultado'), 'denied')
    await user.type(screen.getByLabelText('Actor (id. de cuenta)'), '9')
    await user.click(screen.getByRole('button', { name: 'Aplicar filtros' }))

    await waitFor(() => {
      const last = fetchMock.mock.calls.map(([input]) => new URL(String(input), 'http://x')).filter((url) => url.pathname.endsWith('/audit/events')).at(-1)
      expect(last?.searchParams.get('event_type')).toBe('access.denied')
      expect(last?.searchParams.get('outcome')).toBe('denied')
      expect(last?.searchParams.get('actor_id')).toBe('9')
      expect(last?.searchParams.get('start_date')).toBe('2026-11-01')
    })
    await user.click(await screen.findByRole('button', { name: 'Cargar más eventos' }))
    await waitFor(() => expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(3))
    expect(screen.queryByRole('button', { name: 'Cargar más eventos' })).not.toBeInTheDocument()
  })

  it('discards an in-flight events page when the active filters change', async () => {
    const user = userEvent.setup()
    const nextPage = deferred<Response>()
    let nextSignal: AbortSignal | undefined
    routeFetch((url, init) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events' && url.searchParams.get('cursor') === 'next') {
        nextSignal = init?.signal as AbortSignal | undefined
        return nextPage.promise
      }
      if (url.pathname === '/api/v1/staff/audit/events') {
        const eventType = url.searchParams.get('event_type') ?? 'access.denied'
        return jsonResponse(eventsPage([auditEvent({ event_type: eventType })], eventType === 'access.denied' ? 'next' : null))
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-11-01&end_date=2026-11-14')
    render(<AppRouter />)

    await screen.findByRole('table')
    await user.click(screen.getByRole('button', { name: 'Cargar más eventos' }))
    await waitFor(() => expect(nextSignal).toBeDefined())
    await user.selectOptions(screen.getByLabelText('Tipo de evento'), 'auth.login_success')
    await user.click(screen.getByRole('button', { name: 'Aplicar filtros' }))

    expect(await within(await screen.findByRole('table')).findByText('auth.login_success')).toBeInTheDocument()
    expect(nextSignal?.aborted).toBe(true)
    nextPage.resolve(jsonResponse(eventsPage([auditEvent({ event_type: 'auth.mfa_failed' })])))
    await waitFor(() => expect(within(screen.getByRole('table')).queryByText('auth.mfa_failed')).not.toBeInTheDocument())
    expect(within(screen.getByRole('table')).getByText('auth.login_success')).toBeInTheDocument()
  })

  it('validates filters before calling the server', async () => {
    const user = userEvent.setup()
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') return jsonResponse(eventsPage([]))
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-11-01&end_date=2026-11-14')
    render(<AppRouter />)
    await screen.findByTestId('audit-events-empty')
    const callsBefore = fetchMock.mock.calls.length

    await user.clear(screen.getByLabelText('Hasta'))
    await user.type(screen.getByLabelText('Hasta'), '2026-10-01')
    await user.type(screen.getByLabelText('Objetivo (identificador)'), '15')
    await user.click(screen.getByRole('button', { name: 'Aplicar filtros' }))

    expect(screen.getByText('La fecha final debe ser igual o posterior a la inicial.')).toBeInTheDocument()
    expect(screen.getByText('Selecciona el tipo de objetivo para este identificador.')).toBeInTheDocument()
    expect(fetchMock.mock.calls.length).toBe(callsBefore)
  })

  it('shows an empty result only for a successful empty dataset and an error otherwise', async () => {
    let fail = true
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') {
        return fail ? problem('audit_query_unavailable', 503) : jsonResponse(eventsPage([]))
      }
      return undefined
    })
    const user = userEvent.setup()
    window.history.pushState({}, '', '/audit/events')
    render(<AppRouter />)

    expect(await screen.findByText(/Esto no significa que no haya actividad/)).toBeInTheDocument()
    expect(screen.queryByTestId('audit-events-empty')).not.toBeInTheDocument()
    fail = false
    await user.click(screen.getByRole('button', { name: 'Reintentar' }))
    expect(await screen.findByTestId('audit-events-empty')).toBeInTheDocument()
  })

  it('maps server validation codes to safe actionable messages', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') {
        return problem('audit_period_too_long', 422, { field_errors: { end_date: ['x'] } })
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-01-01&end_date=2026-11-01')
    render(<AppRouter />)
    expect(await screen.findByText(/supera el máximo permitido de 90 días/)).toBeInTheDocument()
  })

  it('re-confirms the session when the backend denies a stale auditor session', async () => {
    let sessionCalls = 0
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) {
        sessionCalls += 1
        return sessionCalls === 1 ? jsonResponse(auditorSession) : problem('staff_access_denied', 403)
      }
      if (url.pathname === '/api/v1/staff/audit/catalog') return problem('staff_access_denied', 403)
      return undefined
    })
    window.history.pushState({}, '', '/audit')
    render(<AppRouter />)
    expect(await screen.findByRole('heading', { name: 'Iniciar sesión en el portal del personal' })).toBeInTheDocument()
    expect(sessionCalls).toBeGreaterThanOrEqual(2)
  })

  it('opens an event detail with sanitized context and related queries', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events/11111111-1111-4111-8111-111111111111') {
        return jsonResponse(auditEvent({ target_type: 'account', target_id: '15' }))
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/events/11111111-1111-4111-8111-111111111111?start_date=2026-11-01&end_date=2026-11-14')
    render(<AppRouter />)

    const detail = await screen.findByTestId('audit-event-detail')
    expect(within(detail).getByText('role_not_permitted')).toBeInTheDocument()
    expect(within(detail).getByText('2026-11-10T15:00:00Z')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Investigar la actividad del actor 9' })).toHaveAttribute(
      'href',
      expect.stringContaining('account_id=9'),
    )
    expect(screen.getByRole('link', { name: 'Ver eventos con la misma correlación' })).toHaveAttribute(
      'href',
      expect.stringContaining('correlation_id=corr-1'),
    )
    expect(screen.getByText(/no prueba que uno haya causado al otro/)).toBeInTheDocument()
  })

  it('reports a missing event as unavailable', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname.startsWith('/api/v1/staff/audit/events/')) return problem('audit_event_not_found', 404)
      return undefined
    })
    window.history.pushState({}, '', '/audit/events/11111111-1111-4111-8111-111111111111')
    render(<AppRouter />)
    expect(await screen.findByText('El evento solicitado no existe o no está disponible.')).toBeInTheDocument()
  })
})
