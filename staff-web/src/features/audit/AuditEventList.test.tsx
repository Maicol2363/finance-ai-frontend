import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from '../../app/router/AppRouter'
import { auditEvent, auditorSession, jsonResponse, period, requestedPaths, routeFetch } from '../../test/auditFixtures'
import { NEW_EVENTS_POLL_MS } from './AuditEventsPage'
import { presetPeriod } from './auditFormat'

function eventsPage(items: unknown[]) {
  return { items, next_cursor: null, read_boundary: '2026-11-14T20:00:00Z', period, filters: {} }
}

function hrefOf(link: HTMLElement): URL {
  return new URL(link.getAttribute('href') ?? '', 'http://x')
}

describe('Security Auditor event list conventions', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/')
    sessionStorage.clear()
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('names events readably, shows origin and role, and pivots on actor and correlation', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') {
        return jsonResponse(eventsPage([
          auditEvent({
            event_type: 'auth.login_failed',
            outcome: 'failure',
            actor_id: '15',
            actor_role: 'user',
            target_type: 'account',
            target_id: '15',
            correlation_id: 'app-login-1',
            context: { reason: 'invalid_credentials', channel: 'customer_app', platform: 'android' },
          }),
          auditEvent({ event_id: '33333333-3333-4333-8333-333333333333', actor_role: null }),
        ]))
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-11-01&end_date=2026-11-14&outcome=failure')
    render(<AppRouter />)

    const rows = within(await screen.findByRole('table')).getAllByRole('row')
    expect(rows[1]).toHaveTextContent('Inicio de sesión fallido')
    expect(rows[1]).toHaveTextContent('auth.login_failed')
    expect(rows[1]).toHaveTextContent('App de clientes · Android')
    expect(rows[1]).toHaveTextContent('Usuario (cliente)')
    expect(rows[2]).toHaveTextContent('Rol no registrado')

    const actor = hrefOf(within(rows[1]).getByRole('link', { name: 'Filtrar eventos del actor 15' }))
    expect(actor.pathname).toBe('/audit/events')
    expect(actor.searchParams.get('actor_id')).toBe('15')
    // The pivot keeps the current period and the filters already applied.
    expect(actor.searchParams.get('outcome')).toBe('failure')
    expect(actor.searchParams.get('start_date')).toBe('2026-11-01')
    const correlation = hrefOf(within(rows[1]).getByRole('link', { name: 'Filtrar eventos con la correlación app-login-1' }))
    expect(correlation.searchParams.get('correlation_id')).toBe('app-login-1')
  })

  it('filters by any of the four roles and explains each field while it has focus', async () => {
    const user = userEvent.setup()
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') return jsonResponse(eventsPage([auditEvent()]))
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-11-01&end_date=2026-11-14')
    render(<AppRouter />)
    await screen.findByRole('table')

    const role = screen.getByLabelText('Rol del actor')
    expect(within(role).getAllByRole('option').map((option) => option.textContent)).toEqual([
      'Cualquiera',
      'Usuario (cliente)',
      'Agente de soporte',
      'Administrador',
      'Auditor de seguridad',
    ])
    const correlation = screen.getByLabelText('Correlación')
    expect(correlation).toHaveAccessibleDescription(expect.stringContaining('misma solicitud u operación'))
    expect(screen.getByLabelText('Tipo de evento')).toHaveAccessibleDescription(expect.stringContaining('La acción registrada'))
    await user.click(correlation)
    expect(correlation.closest('.audit-field')?.querySelector('.audit-field-hint')).toHaveTextContent(
      'Código que comparten todos los eventos de una misma solicitud u operación.',
    )

    await user.selectOptions(role, 'admin')
    await user.click(screen.getByRole('button', { name: 'Aplicar filtros' }))
    await waitFor(() => expect(window.location.search).toContain('actor_role=admin'))
    await waitFor(() =>
      expect(
        fetchMock.mock.calls.some(([input]) => new URL(String(input), 'http://x').searchParams.get('actor_role') === 'admin'),
      ).toBe(true),
    )
  })

  it('applies a quick period and suggests widening an empty result', async () => {
    const user = userEvent.setup()
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') return jsonResponse(eventsPage([]))
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-11-01&end_date=2026-11-14&outcome=denied')
    render(<AppRouter />)

    expect(await screen.findByTestId('audit-events-empty')).toHaveTextContent('prueba ampliar el periodo o quitar filtros')
    await user.click(screen.getByRole('button', { name: 'Últimos 30 días' }))
    const expected = presetPeriod(30, 'America/Bogota')
    await waitFor(() => expect(window.location.search).toContain(`start_date=${expected.start_date}`))
    expect(window.location.search).toContain('outcome=denied')
    expect(await screen.findByRole('button', { name: 'Últimos 30 días' })).toHaveAttribute('aria-pressed', 'true')

    await user.click(await screen.findByRole('button', { name: 'Quitar filtros' }))
    await waitFor(() => expect(window.location.search).not.toContain('outcome='))
    expect(window.location.search).toContain(`start_date=${expected.start_date}`)
  })

  it('announces events recorded after the cutoff without changing the list until asked', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    let recordedLater = false
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') {
        if (!recordedLater) return jsonResponse(eventsPage([auditEvent()]))
        return jsonResponse(eventsPage([
          auditEvent({ event_id: '44444444-4444-4444-8444-444444444444', occurred_at: '2026-11-14T21:00:00Z', event_type: 'auth.logout' }),
          auditEvent(),
        ]))
      }
      return undefined
    })
    window.history.pushState({}, '', '/audit/events')
    render(<AppRouter />)
    expect(within(await screen.findByRole('table')).getAllByRole('row')).toHaveLength(2)
    recordedLater = true

    await vi.advanceTimersByTimeAsync(NEW_EVENTS_POLL_MS)
    expect(await screen.findByTestId('audit-new-events')).toHaveTextContent('Hay 1 evento nuevo desde el corte.')
    // The visible snapshot does not change on its own.
    expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(2)

    await user.click(screen.getByRole('button', { name: 'Mostrar ahora' }))
    await waitFor(() => expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(3))
    expect(screen.queryByTestId('audit-new-events')).not.toBeInTheDocument()
  })

  it('does not poll a period that ended before today', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return jsonResponse(auditorSession)
      if (url.pathname === '/api/v1/staff/audit/events') return jsonResponse(eventsPage([auditEvent()]))
      return undefined
    })
    window.history.pushState({}, '', '/audit/events?start_date=2026-01-01&end_date=2026-01-31')
    render(<AppRouter />)
    await screen.findByRole('table')
    const before = requestedPaths(fetchMock).filter((path) => path.startsWith('/api/v1/staff/audit/events')).length

    await vi.advanceTimersByTimeAsync(NEW_EVENTS_POLL_MS * 2)

    expect(requestedPaths(fetchMock).filter((path) => path.startsWith('/api/v1/staff/audit/events'))).toHaveLength(before)
  })
})
