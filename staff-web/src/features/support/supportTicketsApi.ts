const TICKETS_PATH = '/api/v1/staff/support/tickets'

export type TicketStatus = 'open' | 'in_progress' | 'escalated' | 'resolved'

export interface SupportTicket {
  id: number
  subject: string
  status: TicketStatus
  created_at: string
  assigned_staff_user_id: number | null
}

export interface SupportTicketDetail extends SupportTicket {
  category: string
  description: string
}

export class SupportTicketsApiError extends Error {
  readonly status: number

  constructor(status: number) {
    super('No fue posible completar la solicitud de soporte.')
    this.name = 'SupportTicketsApiError'
    this.status = status
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${TICKETS_PATH}${path}`, {
    ...init,
    cache: 'no-store',
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      'X-Staff-Request': '1',
      'X-Correlation-ID': crypto.randomUUID(),
      ...init?.headers,
    },
  })
  if (!response.ok) throw new SupportTicketsApiError(response.status)
  return (await response.json()) as T
}

export const supportTicketsApi = {
  list(status: TicketStatus | 'all', signal?: AbortSignal): Promise<SupportTicket[]> {
    const query = status === 'all' ? '' : `?status=${encodeURIComponent(status)}`
    return request(query, { method: 'GET', signal })
  },

  detail(id: number, signal?: AbortSignal): Promise<SupportTicketDetail> {
    return request(`/${id}`, { method: 'GET', signal })
  },

  claim(id: number): Promise<SupportTicket> {
    return request(`/${id}/claim`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    })
  },
}
