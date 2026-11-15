import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { EscalationsPage } from './EscalationsPage'

vi.mock('../../shared/auth/useStaffAuth', () => ({
  useStaffAuth: () => ({ session: { user: { id: 1, email: 'admin@example.test', role: 'admin' } } }),
}))

const row = {
  id: 3,
  subject: 'No puedo entrar',
  category: 'account',
  created_at: '2026-11-12T12:00:00Z',
  owner_admin_id: null as number | null,
  originating_agent_id: 2,
  owned_by_me: false,
}

function caseFor(overrides: Record<string, unknown> = {}) {
  return {
    ticket: {
      id: 3,
      subject: 'No puedo entrar',
      category: 'account',
      description: 'Detalle del problema',
      status: 'escalated',
      created_at: '2026-11-12T12:00:00Z',
      assigned_staff_user_id: 2,
      resolution_summary: null,
    },
    customer: { id: 9, email: 'customer@example.com', is_active: true },
    messages: [{ id: 1, author_user_id: 9, body: 'Hola, ayuda', created_at: '2026-11-12T12:05:00Z' }],
    history: [
      {
        id: 1,
        actor_user_id: 2,
        event_type: 'ticket_escalated',
        previous_status: 'in_progress',
        new_status: 'escalated',
        previous_assignee_user_id: null,
        new_assignee_user_id: null,
        created_at: '2026-11-12T12:10:00Z',
        internal_reason: 'ESCALADO: excepción de política',
      },
    ],
    escalation_reason: 'ESCALADO: excepción de política',
    owner_admin_id: null,
    owned_by_me: false,
    originating_agent: { user_id: 2, can_receive_return: true },
    ...overrides,
  }
}

function jsonResponse(body: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

type Handler = (url: string, init?: RequestInit) => Response | Promise<Response>

function routeFetch(routes: Record<string, Handler>) {
  vi.mocked(fetch).mockImplementation(async (input, init) => {
    const url = String(input).replace('/api/v1/staff/admin', '')
    const key = `${init?.method ?? 'GET'} ${url.split('?')[0]}`
    const handler = routes[key]
    if (!handler) throw new Error(`Unexpected request: ${key}`)
    return handler(url, init)
  })
}

function bodies(path: string): unknown[] {
  return vi.mocked(fetch).mock.calls
    .filter(([url, init]) => String(url).endsWith(path) && init?.method === 'POST')
    .map(([, init]) => JSON.parse(String(init?.body)))
}

describe('EscalationsPage (ADM-05)', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })
  afterEach(() => vi.unstubAllGlobals())

  it('lists escalated cases, labels ownership and refetches with the selected scope', async () => {
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([row, { ...row, id: 4, owner_admin_id: 8 }]),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)

    expect(await screen.findByText('Ticket #3')).toBeInTheDocument()
    const cards = screen.getAllByRole('listitem')
    expect(within(cards[0]).getByText('Sin reclamar')).toBeInTheDocument()
    expect(within(cards[1]).getByText('Otro administrador')).toBeInTheDocument()
    expect(within(cards[1]).queryByRole('button', { name: 'Reclamar caso' })).not.toBeInTheDocument()
    expect(String(vi.mocked(fetch).mock.calls[0]![0])).toContain('scope=all&limit=100')

    await user.click(screen.getByRole('button', { name: 'Sin reclamar' }))
    await waitFor(() => expect(String(vi.mocked(fetch).mock.calls.at(-1)![0])).toContain('scope=unclaimed'))
    expect(screen.getByRole('button', { name: 'Sin reclamar' })).toHaveAttribute('aria-pressed', 'true')
  })

  it('shows an empty state when nothing is escalated', async () => {
    routeFetch({ 'GET /tickets/escalated': () => jsonResponse([]) })
    render(<EscalationsPage />)

    expect(await screen.findByText('No hay casos escalados en esta vista')).toBeInTheDocument()
  })

  it('claims a case and then offers the owner actions with staff-only reasons labelled', async () => {
    let claimed = false
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([{ ...row, owner_admin_id: claimed ? 1 : null, owned_by_me: claimed }]),
      'POST /tickets/3/claim': () => {
        claimed = true
        return jsonResponse(caseFor({ owner_admin_id: 1, owned_by_me: true }))
      },
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)

    await user.click(await screen.findByRole('button', { name: 'Reclamar caso' }))

    const panel = await screen.findByTestId('admin-case')
    expect(screen.getByTestId('admin-escalations-notice')).toHaveTextContent('Caso reclamado')
    expect(within(panel).getByTestId('admin-escalation-reason')).toHaveTextContent('ESCALADO: excepción de política')
    expect(within(panel).getAllByText('Solo personal').length).toBeGreaterThan(0)
    expect(within(panel).getByTestId('admin-origin-note')).toHaveTextContent('volverá a él en atención')
    expect(within(panel).getByTestId('admin-messages')).toHaveTextContent('Cliente')
    expect(within(panel).getByTestId('admin-case-actions')).toBeInTheDocument()
    expect(panel).toHaveTextContent('no muestra saldos, movimientos, recibos ni credenciales')
    expect(bodies('/tickets/3/claim')).toEqual([{}])
  })

  it('shows a read-only case when another administrator owns it', async () => {
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([{ ...row, owner_admin_id: 8 }]),
      'GET /tickets/3': () => jsonResponse(caseFor({ owner_admin_id: 8, owned_by_me: false })),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)

    await user.click(await screen.findByRole('button', { name: 'Ver caso' }))

    expect(await screen.findByTestId('admin-case-readonly')).toBeInTheDocument()
    expect(screen.queryByTestId('admin-case-actions')).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Reclamar este caso' })).not.toBeInTheDocument()
  })

  it('explains a claim conflict and refreshes the list', async () => {
    let lists = 0
    routeFetch({
      'GET /tickets/escalated': () => {
        lists += 1
        return jsonResponse([{ ...row, owner_admin_id: lists > 1 ? 8 : null }])
      },
      'POST /tickets/3/claim': () => jsonResponse({ code: 'escalation_claim_conflict' }, 409, { 'X-Correlation-ID': 'c-claim' }),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)

    await user.click(await screen.findByRole('button', { name: 'Reclamar caso' }))

    expect(await screen.findByTestId('admin-error')).toHaveTextContent('Otro administrador tomó este caso primero')
    await waitFor(() => expect(screen.getByText('Otro administrador')).toBeInTheDocument())
    expect(screen.queryByTestId('admin-case')).not.toBeInTheDocument()
  })

  async function openOwnedCase(user: ReturnType<typeof userEvent.setup>) {
    await user.click(await screen.findByRole('button', { name: 'Ver caso' }))
    return screen.findByTestId('admin-case-actions')
  }

  it('sends a customer-visible reply, then reloads the case', async () => {
    let replied = false
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([{ ...row, owner_admin_id: 1, owned_by_me: true }]),
      'GET /tickets/3': () => jsonResponse(caseFor({
        owner_admin_id: 1,
        owned_by_me: true,
        messages: replied
          ? [{ id: 1, author_user_id: 9, body: 'Hola, ayuda', created_at: '2026-11-12T12:05:00Z' }, { id: 2, author_user_id: 1, body: 'Estamos revisando', created_at: '2026-11-12T12:20:00Z' }]
          : [],
      })),
      'POST /tickets/3/messages': () => {
        replied = true
        return new Response(null, { status: 204 })
      },
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)
    await openOwnedCase(user)

    await user.click(screen.getByRole('button', { name: 'Responder al cliente' }))
    expect(screen.getByText(/El cliente verá este mensaje/)).toBeInTheDocument()
    const send = screen.getByRole('button', { name: 'Enviar respuesta' })
    expect(send).toBeDisabled()
    await user.type(screen.getByLabelText('Mensaje para el cliente'), '   ')
    expect(send).toBeDisabled()
    await user.type(screen.getByLabelText('Mensaje para el cliente'), '  Estamos revisando  ')
    await user.click(send)

    await waitFor(() => expect(screen.getByTestId('admin-messages')).toHaveTextContent('Estamos revisando'))
    expect(screen.getByTestId('admin-messages')).toHaveTextContent('Tú (administrador)')
    expect(bodies('/tickets/3/messages')).toEqual([{ body: 'Estamos revisando' }])
  })

  it('requires a summary and confirmation to resolve, then closes the case and refreshes', async () => {
    let lists = 0
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse(lists++ === 0 ? [{ ...row, owner_admin_id: 1, owned_by_me: true }] : []),
      'GET /tickets/3': () => jsonResponse(caseFor({ owner_admin_id: 1, owned_by_me: true })),
      'POST /tickets/3/resolve': () => new Response(null, { status: 204 }),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)
    await openOwnedCase(user)

    await user.click(screen.getByRole('button', { name: 'Resolver caso' }))
    expect(screen.getByText(/El cliente verá este resumen/)).toBeInTheDocument()
    const submit = within(screen.getByRole('form', { name: 'Resolver' })).getByRole('button', { name: 'Resolver caso' })
    await user.type(screen.getByLabelText('Resumen de resolución (obligatorio)'), 'Acceso restablecido')
    expect(submit).toBeDisabled()
    await user.click(screen.getByRole('checkbox'))
    await user.click(submit)

    await waitFor(() => expect(screen.getByTestId('admin-escalations-notice')).toHaveTextContent('Caso resuelto'))
    expect(screen.queryByTestId('admin-case')).not.toBeInTheDocument()
    expect(bodies('/tickets/3/resolve')).toEqual([{ summary: 'Acceso restablecido' }])
    expect(await screen.findByText('No hay casos escalados en esta vista')).toBeInTheDocument()
  })

  it.each([
    ['in_progress', /continúa atendiéndolo/],
    ['open', /volvió a la cola de soporte sin asignar/],
  ])('requires a staff-only reason to return a case and reports the %s outcome', async (status, message) => {
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([{ ...row, owner_admin_id: 1, owned_by_me: true }]),
      'GET /tickets/3': () => jsonResponse(caseFor({ owner_admin_id: 1, owned_by_me: true })),
      'POST /tickets/3/return': () => jsonResponse({ status, assigned_staff_user_id: status === 'open' ? null : 2 }),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)
    await openOwnedCase(user)

    await user.click(screen.getByRole('button', { name: 'Devolver a soporte' }))
    expect(screen.getByText(/Solo lo verá el personal autorizado/)).toBeInTheDocument()
    const form = screen.getByRole('form', { name: 'Devolver' })
    await user.type(within(form).getByLabelText('Motivo de devolución (obligatorio)'), 'Verificado, continúa soporte')
    expect(within(form).getByRole('button', { name: 'Devolver caso' })).toBeDisabled()
    await user.click(within(form).getByRole('checkbox'))
    await user.click(within(form).getByRole('button', { name: 'Devolver caso' }))

    await waitFor(() => expect(screen.getByTestId('admin-escalations-notice')).toHaveTextContent(message))
    expect(bodies('/tickets/3/return')).toEqual([{ reason: 'Verificado, continúa soporte' }])
  })

  it('warns that an ineligible originating agent sends the case back unassigned', async () => {
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([{ ...row, owner_admin_id: 1, owned_by_me: true }]),
      'GET /tickets/3': () => jsonResponse(caseFor({
        owner_admin_id: 1,
        owned_by_me: true,
        originating_agent: { user_id: 2, can_receive_return: false },
      })),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)

    await openOwnedCase(user)

    expect(screen.getByTestId('admin-origin-note')).toHaveTextContent('volverá a la cola sin asignar')
  })

  it('keeps the form and shows the server refusal when the case changed meanwhile', async () => {
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([{ ...row, owner_admin_id: 1, owned_by_me: true }]),
      'GET /tickets/3': () => jsonResponse(caseFor({ owner_admin_id: 1, owned_by_me: true })),
      'POST /tickets/3/resolve': () => jsonResponse({ code: 'support_ticket_state_conflict' }, 409, { 'X-Correlation-ID': 'c-state' }),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)
    await openOwnedCase(user)
    await user.click(screen.getByRole('button', { name: 'Resolver caso' }))
    await user.type(screen.getByLabelText('Resumen de resolución (obligatorio)'), 'Resumen')
    await user.click(screen.getByRole('checkbox'))
    await user.click(within(screen.getByRole('form', { name: 'Resolver' })).getByRole('button', { name: 'Resolver caso' }))

    expect(await screen.findByTestId('admin-error')).toHaveTextContent('El caso cambió de estado')
    expect(screen.getByRole('form', { name: 'Resolver' })).toBeInTheDocument()
  })

  it('shows the most recently requested case even when an earlier response arrives later', async () => {
    let finishFirst: ((response: Response) => void) | undefined
    routeFetch({
      'GET /tickets/escalated': () => jsonResponse([row, { ...row, id: 4, subject: 'Segundo caso' }]),
      'GET /tickets/3': () => new Promise<Response>((resolve) => { finishFirst = resolve }),
      'GET /tickets/4': () => jsonResponse(caseFor({ ticket: { ...caseFor().ticket, id: 4, subject: 'Segundo caso' } })),
    })
    const user = userEvent.setup()
    render(<EscalationsPage />)
    const buttons = await screen.findAllByRole('button', { name: 'Ver caso' })

    await user.click(buttons[0])
    await user.click(buttons[1])
    expect(await screen.findByTestId('admin-case')).toHaveTextContent('CASO ESCALADO #4')
    finishFirst?.(jsonResponse(caseFor()))
    await new Promise((resolve) => setTimeout(resolve, 50))

    expect(screen.getByTestId('admin-case')).toHaveTextContent('CASO ESCALADO #4')
    expect(screen.queryByText('CASO ESCALADO #3')).not.toBeInTheDocument()
  })

  it('shows a safe queue failure with a retry', async () => {
    routeFetch({ 'GET /tickets/escalated': () => jsonResponse({ code: 'staff_access_denied' }, 403, { 'X-Correlation-ID': 'c-q' }) })
    render(<EscalationsPage />)

    expect(await screen.findByTestId('admin-error')).toHaveTextContent('Tu sesión ya no tiene permiso de administración')
    expect(screen.queryByText('Ticket #3')).not.toBeInTheDocument()
  })
})
