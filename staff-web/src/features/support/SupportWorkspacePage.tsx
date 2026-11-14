import { useCallback, useEffect, useState } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { SupportDiagnosticPanel } from './SupportDiagnosticPanel'
import {
  safeSupportDiagnostic,
  safeSupportMessage,
  supportTicketsApi,
  type SupportDiagnostic,
  type SupportTicket,
  type SupportTicketDetail,
  type TicketStatus,
} from './supportTicketsApi'

const filters: Array<{ value: TicketStatus | 'all'; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'open', label: 'Abiertos' },
  { value: 'in_progress', label: 'En atención' },
  { value: 'escalated', label: 'Escalados' },
  { value: 'resolved', label: 'Resueltos' },
]

const statusLabels: Record<TicketStatus, string> = {
  open: 'Abierto',
  in_progress: 'En atención',
  escalated: 'Escalado',
  resolved: 'Resuelto',
}

interface SupportFailure {
  message: string
  diagnostic: SupportDiagnostic
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat('es-CO', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
}

export function SupportWorkspacePage() {
  const { session } = useStaffAuth()
  const [filter, setFilter] = useState<TicketStatus | 'all'>('all')
  const [tickets, setTickets] = useState<SupportTicket[]>([])
  const [loading, setLoading] = useState(true)
  const [queueFailure, setQueueFailure] = useState<SupportFailure | null>(null)
  const [actionFailure, setActionFailure] = useState<SupportFailure | null>(null)
  const [notice, setNotice] = useState('')
  const [busyId, setBusyId] = useState<number | null>(null)
  const [detail, setDetail] = useState<SupportTicketDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)

  const refresh = useCallback(async (signal?: AbortSignal) => {
    setLoading(true)
    setQueueFailure(null)
    try {
      setTickets(await supportTicketsApi.list(filter, signal))
    } catch (failure) {
      if (!signal?.aborted) {
        setQueueFailure({
          message: safeSupportMessage(failure, 'queue'),
          diagnostic: safeSupportDiagnostic(failure, 'queue'),
        })
      }
    } finally {
      if (!signal?.aborted) setLoading(false)
    }
  }, [filter])

  useEffect(() => {
    const controller = new AbortController()
    void refresh(controller.signal)
    return () => controller.abort()
  }, [refresh])

  async function openDetail(ticket: SupportTicket) {
    setDetail(null)
    setDetailLoading(true)
    try {
      setDetail(await supportTicketsApi.detail(ticket.id))
      setActionFailure(null)
    } catch (failure) {
      setActionFailure({
        message: safeSupportMessage(failure, 'detail'),
        diagnostic: safeSupportDiagnostic(failure, 'detail'),
      })
    } finally {
      setDetailLoading(false)
    }
  }

  async function claim(ticket: SupportTicket) {
    setBusyId(ticket.id)
    setNotice('')
    setActionFailure(null)
    try {
      const claimed = await supportTicketsApi.claim(ticket.id)
      setTickets((current) => filter === 'open'
        ? current.filter((item) => item.id !== claimed.id)
        : current.map((item) => item.id === claimed.id ? claimed : item))
      setNotice('Ticket reclamado. Ya puedes consultar su contexto autorizado.')
      await openDetail(claimed)
    } catch (failure) {
      setActionFailure({
        message: safeSupportMessage(failure, 'claim'),
        diagnostic: safeSupportDiagnostic(failure, 'claim'),
      })
      await refresh()
    } finally {
      setBusyId(null)
    }
  }

  return (
    <section aria-labelledby="support-title" className="support-workspace">
      <div className="page-heading">
        <div>
          <p className="eyebrow">AGENTE DE SOPORTE</p>
          <h1 id="support-title">Atención al cliente</h1>
          <p>Consulta la cola y reclama un caso para empezar a atenderlo.</p>
        </div>
        <button className="secondary-button" disabled={loading} onClick={() => void refresh()} type="button">Actualizar</button>
      </div>

      <div aria-label="Filtrar tickets por estado" className="support-filters" role="group">
        {filters.map((item) => (
          <button
            aria-pressed={filter === item.value}
            className={filter === item.value ? 'filter-button is-selected' : 'filter-button'}
            key={item.value}
            onClick={() => { setFilter(item.value); setDetail(null); setActionFailure(null) }}
            type="button"
          >{item.label}</button>
        ))}
      </div>

      <p aria-live="polite" className="support-notice">{notice}</p>
      {queueFailure && <>
        <div className="support-error" role="alert">{queueFailure.message}<button onClick={() => void refresh()} type="button">Reintentar</button></div>
        <SupportDiagnosticPanel diagnostic={queueFailure.diagnostic} id="support-queue-diagnostic" />
      </>}
      {actionFailure && <>
        <div className="support-error" role="alert">{actionFailure.message}</div>
        <SupportDiagnosticPanel diagnostic={actionFailure.diagnostic} id="support-action-diagnostic" />
      </>}
      {loading && <p aria-live="polite" className="support-loading">Cargando tickets…</p>}
      {!loading && !queueFailure && tickets.length === 0 && !detail && !detailLoading && <div className="support-empty"><h2>No hay tickets en esta vista</h2><p>Prueba otro filtro o actualiza la cola más tarde.</p></div>}

      {(!loading && tickets.length > 0 || detail !== null || detailLoading) && (
        <div className="support-content">
          <div aria-label="Tickets de soporte" className="ticket-list" role="list">
            {tickets.length === 0 && <p className="support-empty-list">La cola está vacía para este filtro.</p>}
            {tickets.map((ticket) => {
              const mine = ticket.assigned_staff_user_id === session?.user.id
              const assigned = ticket.assigned_staff_user_id !== null
              return (
                <article className="ticket-card" key={ticket.id} role="listitem">
                  <div className="ticket-card-heading">
                    <span className="ticket-id">Ticket #{ticket.id}</span>
                    <span className={`ticket-status status-${ticket.status}`}>{statusLabels[ticket.status]}</span>
                  </div>
                  <h2>{ticket.subject}</h2>
                  <dl className="ticket-meta">
                    <div><dt>Creado</dt><dd>{formatDate(ticket.created_at)}</dd></div>
                    <div><dt>Asignación</dt><dd>{mine ? 'Tú' : assigned ? 'Otro agente' : 'Sin asignar'}</dd></div>
                  </dl>
                  <div className="ticket-actions">
                    {ticket.status === 'open' && !assigned && <button className="primary-button" disabled={busyId === ticket.id} onClick={() => void claim(ticket)} type="button">{busyId === ticket.id ? 'Reclamando…' : 'Reclamar ticket'}</button>}
                    {mine && <button className="secondary-button" onClick={() => void openDetail(ticket)} type="button">Ver contexto</button>}
                  </div>
                </article>
              )
            })}
          </div>

          <aside aria-label="Contexto del ticket asignado" className="ticket-detail" aria-live="polite">
            {detailLoading && <p>Cargando contexto autorizado…</p>}
            {!detailLoading && !detail && <p>Reclama un ticket para consultar su contexto autorizado.</p>}
            {detail && <>
              <p className="eyebrow">TICKET #{detail.id}</p>
              <h2>{detail.subject}</h2>
              <dl className="ticket-detail-meta"><div><dt>Estado</dt><dd>{statusLabels[detail.status]}</dd></div><div><dt>Categoría</dt><dd>{detail.category}</dd></div><div><dt>Creado</dt><dd>{formatDate(detail.created_at)}</dd></div></dl>
              <h3>Descripción</h3>
              <p className="ticket-description">{detail.description}</p>
              <p className="privacy-note">Los datos financieros y las credenciales no están disponibles en el portal de soporte.</p>
            </>}
          </aside>
        </div>
      )}
    </section>
  )
}
