import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { SupportTicketsApiError, supportTicketsApi } from './supportTicketsApi'
import { SupportWorkspacePage } from './SupportWorkspacePage'

const { mockSession } = vi.hoisted(() => ({
  mockSession: { user: { id: 42, role: 'support_agent', email: 'agent@example.test' } },
}))

vi.mock('../../shared/auth/useStaffAuth', () => ({
  useStaffAuth: () => ({ session: mockSession }),
}))

const ticket = {
  id: 7,
  subject: 'Ayuda con la cuenta',
  status: 'open' as const,
  created_at: '2026-11-12T12:00:00Z',
  assigned_staff_user_id: null,
}

function jsonResponse(body: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

function expectSafeSupportReport(
  report: string,
  details: { code: string; operation: string; path: string; correlationId: string; privateValues: string[] },
) {
  expect(report).toContain(`Código del error: ${details.code}`)
  expect(report).toContain(`Operación: staff.support.${details.operation}`)
  expect(report).toContain(`Ubicación de la API: ${details.path}`)
  expect(report).toContain(`Id. de solicitud/correlación: ${details.correlationId}`)
  expect(report).toContain('Plataforma: web')
  expect(report).toContain('Hora UTC: ')
  expect(report).toContain('Motivo: ')
  for (const privateValue of details.privateValues) expect(report).not.toContain(privateValue)
}

describe('SupportWorkspacePage', () => {
  beforeEach(() => vi.restoreAllMocks())

  it('loads a limited queue, claims through the API, then shows authorized detail', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse([ticket]))
      .mockResolvedValueOnce(jsonResponse({ ...ticket, status: 'in_progress', assigned_staff_user_id: 42 }))
      .mockResolvedValueOnce(jsonResponse({ ...ticket, status: 'in_progress', assigned_staff_user_id: 42, category: 'general', description: 'Detalle autorizado' }))
    const user = userEvent.setup()
    render(<SupportWorkspacePage />)

    expect(await screen.findByText('Ayuda con la cuenta')).toBeInTheDocument()
    expect(screen.queryByText('Detalle autorizado')).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Reclamar ticket' }))

    expect(await screen.findByText('Detalle autorizado')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledTimes(4)
    expect(fetchMock.mock.calls[1]?.[1]).toMatchObject({ method: 'POST', credentials: 'include' })
    expect(new Headers(fetchMock.mock.calls[1]?.[1]?.headers).get('X-Staff-Request')).toBe('1')
  })

  it('keeps the detail visible after claiming the last open ticket in that filter', async () => {
    const claimed = { ...ticket, status: 'in_progress' as const, assigned_staff_user_id: 42 }
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse([ticket]))
      .mockResolvedValueOnce(jsonResponse([ticket]))
      .mockResolvedValueOnce(jsonResponse(claimed))
      .mockResolvedValueOnce(jsonResponse({ ...claimed, category: 'general', description: 'Detalle autorizado' }))
    const user = userEvent.setup()
    render(<SupportWorkspacePage />)

    await user.click(await screen.findByRole('button', { name: 'Abiertos' }))
    await user.click(await screen.findByRole('button', { name: 'Reclamar ticket' }))

    expect(await screen.findByText('Detalle autorizado')).toBeInTheDocument()
    expect(screen.getByText('La cola está vacía para este filtro.')).toBeInTheDocument()
  })

  it('shows and copies a privacy-safe queue diagnostic', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(jsonResponse(
        { code: 'internal_error', detail: 'agent@example.test private-ticket-body Bearer raw-token' },
        500,
        { 'X-Correlation-ID': 'queue-corr-1' },
      ))
    const writeText = vi.fn<Clipboard['writeText']>().mockResolvedValue()
    const previousClipboard = Object.getOwnPropertyDescriptor(navigator, 'clipboard')
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })

    try {
      render(<SupportWorkspacePage />)

      const report = (await screen.findByLabelText('Contenido del informe de diagnóstico de soporte')).textContent ?? ''
      expectSafeSupportReport(report, {
        code: 'internal_error',
        operation: 'queue',
        path: '/api/v1/staff/support/tickets',
        correlationId: 'queue-corr-1',
        privateValues: ['agent@example.test', 'private-ticket-body', 'raw-token', 'Bearer'],
      })
      fireEvent.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))
      expect(writeText).toHaveBeenCalledExactlyOnceWith(report)
    } finally {
      if (previousClipboard) Object.defineProperty(navigator, 'clipboard', previousClipboard)
      else Reflect.deleteProperty(navigator, 'clipboard')
    }
  })

  it('shows a safe claim conflict diagnostic without server details or the ticket id in the API path', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse([ticket]))
      .mockResolvedValueOnce(jsonResponse(
        { code: 'support_ticket_claim_conflict', detail: 'other-agent@example.test private-note access-token' },
        409,
        { 'X-Correlation-ID': 'claim-corr-2' },
      ))
      .mockResolvedValueOnce(jsonResponse([{ ...ticket, assigned_staff_user_id: 88 }]))
    const user = userEvent.setup()
    render(<SupportWorkspacePage />)

    await user.click(await screen.findByRole('button', { name: 'Reclamar ticket' }))

    expect(await screen.findByText(/Otro agente reclamó este ticket primero/)).toBeInTheDocument()
    const report = (await screen.findByLabelText('Contenido del informe de diagnóstico de soporte')).textContent ?? ''
    expectSafeSupportReport(report, {
      code: 'support_ticket_claim_conflict',
      operation: 'claim',
      path: '/api/v1/staff/support/tickets/{ticket_id}/claim',
      correlationId: 'claim-corr-2',
      privateValues: ['other-agent@example.test', 'private-note', 'access-token', '/tickets/7/claim'],
    })
  })

  it('shows a safe detail diagnostic when assigned-ticket context fails', async () => {
    const assignedTicket = { ...ticket, status: 'in_progress' as const, assigned_staff_user_id: 42 }
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse([assignedTicket]))
      .mockResolvedValueOnce(jsonResponse(
        { code: 'staff_access_denied', detail: 'customer@example.test financial-record secret-cookie' },
        403,
        { 'X-Correlation-ID': 'detail-corr-3' },
      ))
    const user = userEvent.setup()
    render(<SupportWorkspacePage />)

    await user.click(await screen.findByRole('button', { name: 'Ver contexto' }))

    const report = (await screen.findByLabelText('Contenido del informe de diagnóstico de soporte')).textContent ?? ''
    expectSafeSupportReport(report, {
      code: 'staff_access_denied',
      operation: 'detail',
      path: '/api/v1/staff/support/tickets/{ticket_id}',
      correlationId: 'detail-corr-3',
      privateValues: ['customer@example.test', 'financial-record', 'secret-cookie', '/tickets/7'],
    })
  })

  it('shows the safe concurrent-claim conflict and reloads the queue', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse([ticket]))
      .mockResolvedValueOnce(jsonResponse({ code: 'support_ticket_claim_conflict' }, 409))
      .mockResolvedValueOnce(jsonResponse([{ ...ticket, assigned_staff_user_id: 88 }]))
    const user = userEvent.setup()
    render(<SupportWorkspacePage />)

    await user.click(await screen.findByRole('button', { name: 'Reclamar ticket' }))
    expect(await screen.findByText(/Otro agente reclamó este ticket primero/)).toBeInTheDocument()
  })

  it('filters by the selected status using the API', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse([ticket]))
      .mockResolvedValueOnce(jsonResponse([]))
    const user = userEvent.setup()
    render(<SupportWorkspacePage />)
    await user.click(await screen.findByRole('button', { name: 'Escalados' }))

    await waitFor(() => expect(fetchMock).toHaveBeenLastCalledWith(
      expect.stringContaining('?status=escalated'),
      expect.objectContaining({ method: 'GET' }),
    ))
    expect(await screen.findByText('No hay tickets en esta vista')).toBeInTheDocument()
  })

  it('offers a retry after a network failure', async () => {
    vi.spyOn(globalThis, 'fetch').mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce(jsonResponse([]))
    render(<SupportWorkspacePage />)
    expect(await screen.findByRole('alert')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Reintentar' }))
    expect(await screen.findByText('No hay tickets en esta vista')).toBeInTheDocument()
  })
})

describe('supportTicketsApi', () => {
  it('surfaces HTTP conflict status without trusting a client-side success', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(jsonResponse({}, 409))
    await expect(supportTicketsApi.claim(5)).rejects.toMatchObject<Partial<SupportTicketsApiError>>({ status: 409 })
  })

  it('propagates a correlation id and excludes untrusted problem details from the error', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(jsonResponse(
      { code: 'support_ticket_claim_conflict', detail: 'private-note customer@example.test session-token' },
      409,
      { 'X-Correlation-ID': 'server-correlation-4' },
    ))
    const error = await supportTicketsApi.claim(5).catch((failure: unknown) => failure)

    expect(error).toBeInstanceOf(SupportTicketsApiError)
    expect(error).toMatchObject({
      status: 409,
      code: 'support_ticket_claim_conflict',
      correlationId: 'server-correlation-4',
      operation: 'claim',
    })
    expect((error as Error).message).not.toMatch(/private-note|customer@example\.test|session-token/)
    const headers = new Headers(fetchMock.mock.calls[0]?.[1]?.headers)
    expect(headers.get('X-Correlation-ID')).toMatch(/^[\da-f-]{36}$/i)
  })
})
