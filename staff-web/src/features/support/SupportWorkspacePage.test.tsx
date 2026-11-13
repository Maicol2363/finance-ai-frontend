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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
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
    expect(fetchMock).toHaveBeenCalledTimes(3)
    expect(fetchMock.mock.calls[1]?.[1]).toMatchObject({ method: 'POST', credentials: 'include' })
    expect(new Headers(fetchMock.mock.calls[1]?.[1]?.headers).get('X-Staff-Request')).toBe('1')
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
})
