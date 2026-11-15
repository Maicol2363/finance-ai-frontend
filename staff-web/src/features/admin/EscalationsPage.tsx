import { useCallback, useEffect, useRef, useState } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import {
  adminApi,
  type AdminCase,
  type EscalatedTicketItem,
  type EscalationScope,
} from './adminApi'
import { AdminFailureNotice, type AdminFailure } from './AdminFailureNotice'
import { EscalationCasePanel } from './EscalationCasePanel'
import { formatDateTime } from './adminFormat'
import { useAdminFailure } from './useAdminFailure'

const SCOPES: ReadonlyArray<{ value: EscalationScope; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'unclaimed', label: 'Sin reclamar' },
  { value: 'mine', label: 'Míos' },
]

/** ADM-05 queue of tickets escalated by Support Agents. */
export function EscalationsPage() {
  const { session } = useStaffAuth()
  const toFailure = useAdminFailure()
  const [scope, setScope] = useState<EscalationScope>('all')
  const [tickets, setTickets] = useState<EscalatedTicketItem[]>([])
  const [loading, setLoading] = useState(true)
  const [queueFailure, setQueueFailure] = useState<AdminFailure | null>(null)
  const [actionFailure, setActionFailure] = useState<AdminFailure | null>(null)
  const [notice, setNotice] = useState('')
  const [openCase, setOpenCase] = useState<AdminCase | null>(null)
  const [caseLoading, setCaseLoading] = useState(false)
  const [busyId, setBusyId] = useState<number | null>(null)
  // Only the most recent case request may update the panel (a slow earlier response must not win).
  const caseRequest = useRef(0)

  const refresh = useCallback(async (signal?: AbortSignal) => {
    setLoading(true)
    setQueueFailure(null)
    try {
      setTickets(await adminApi.escalated(scope, signal))
    } catch (error) {
      if (!signal?.aborted) {
        setQueueFailure(toFailure(error, 'queue'))
      }
    } finally {
      if (!signal?.aborted) setLoading(false)
    }
  }, [scope])

  useEffect(() => {
    const controller = new AbortController()
    void refresh(controller.signal)
    return () => controller.abort()
  }, [refresh])

  async function open(ticket: EscalatedTicketItem): Promise<void> {
    const requestId = ++caseRequest.current
    setCaseLoading(true)
    setOpenCase(null)
    setActionFailure(null)
    try {
      const loaded = await adminApi.case(ticket.id)
      if (requestId === caseRequest.current) setOpenCase(loaded)
    } catch (error) {
      if (requestId === caseRequest.current) {
        setActionFailure(toFailure(error, 'case'))
      }
    } finally {
      if (requestId === caseRequest.current) setCaseLoading(false)
    }
  }

  async function claim(ticketId: number): Promise<void> {
    setBusyId(ticketId)
    setNotice('')
    setActionFailure(null)
    const requestId = ++caseRequest.current
    try {
      const claimed = await adminApi.claim(ticketId)
      if (requestId === caseRequest.current) setOpenCase(claimed)
      setNotice('Caso reclamado. Ahora eres el único administrador que puede responder, resolver o devolverlo.')
    } catch (error) {
      setActionFailure(toFailure(error, 'claim'))
    } finally {
      setBusyId(null)
      await refresh()
    }
  }

  function handleFinished(message: string): void {
    setNotice(message)
    setOpenCase(null)
    void refresh()
  }

  async function reloadCase(id: number): Promise<void> {
    const requestId = ++caseRequest.current
    try {
      const loaded = await adminApi.case(id)
      if (requestId === caseRequest.current) setOpenCase(loaded)
    } catch (error) {
      if (requestId !== caseRequest.current) return
      setOpenCase(null)
      setActionFailure(toFailure(error, 'case'))
    }
  }

  return (
    <div className="admin-section" data-testid="admin-escalations">
      <div className="admin-toolbar">
        <h2>Casos escalados por soporte</h2>
        <button className="secondary-button" disabled={loading} onClick={() => void refresh()} type="button">Actualizar</button>
      </div>
      <div aria-label="Filtrar casos" className="support-filters" role="group">
        {SCOPES.map((item) => (
          <button
            aria-pressed={scope === item.value}
            className={scope === item.value ? 'filter-button is-selected' : 'filter-button'}
            key={item.value}
            onClick={() => { caseRequest.current += 1; setScope(item.value); setOpenCase(null); setCaseLoading(false) }}
            type="button"
          >{item.label}</button>
        ))}
      </div>
      <p aria-live="polite" className="admin-notice" data-testid="admin-escalations-notice">{notice}</p>
      {queueFailure && <AdminFailureNotice failure={queueFailure} />}
      {actionFailure && <AdminFailureNotice failure={actionFailure} />}
      {loading && <p aria-live="polite" className="async-state">Cargando casos escalados…</p>}
      {!loading && !queueFailure && tickets.length === 0 && (
        <div className="support-empty"><h3>No hay casos escalados en esta vista</h3><p>Cuando soporte escale un caso aparecerá aquí.</p></div>
      )}

      {(tickets.length > 0 || openCase !== null || caseLoading) && (
        <div className="support-content">
          <div aria-label="Casos escalados" className="ticket-list" role="list">
            {tickets.map((ticket) => (
              <article className="ticket-card" key={ticket.id} role="listitem">
                <div className="ticket-card-heading">
                  <span className="ticket-id">Ticket #{ticket.id}</span>
                  <span className="ticket-status">
                    {ticket.owned_by_me ? 'Tuyo' : ticket.owner_admin_id !== null ? 'Otro administrador' : 'Sin reclamar'}
                  </span>
                </div>
                <h3>{ticket.subject}</h3>
                <dl className="ticket-meta">
                  <div><dt>Categoría</dt><dd>{ticket.category}</dd></div>
                  <div><dt>Creado</dt><dd>{formatDateTime(ticket.created_at)}</dd></div>
                </dl>
                <div className="ticket-actions">
                  {ticket.owner_admin_id === null && (
                    <button className="primary-button" disabled={busyId === ticket.id} onClick={() => void claim(ticket.id)} type="button">
                      {busyId === ticket.id ? 'Reclamando…' : 'Reclamar caso'}
                    </button>
                  )}
                  <button className="secondary-button" onClick={() => void open(ticket)} type="button">Ver caso</button>
                </div>
              </article>
            ))}
          </div>
          <aside aria-label="Contexto del caso" aria-live="polite" className="ticket-detail">
            {caseLoading && <p>Cargando el contexto autorizado…</p>}
            {!caseLoading && !openCase && <p>Selecciona un caso para ver su contexto.</p>}
            {openCase && (
              <EscalationCasePanel
                adminId={session?.user.id ?? 0}
                data={openCase}
                key={openCase.ticket.id}
                onChanged={() => void reloadCase(openCase.ticket.id)}
                onClaim={() => void claim(openCase.ticket.id)}
                onFinished={handleFinished}
              />
            )}
          </aside>
        </div>
      )}
    </div>
  )
}
