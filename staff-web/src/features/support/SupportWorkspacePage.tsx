import { useSearchParams } from 'react-router'
import { useSupportPolling } from './useSupportPolling'
import { SupportCasePanel } from './SupportCasePanel'
import { SupportCreateForm } from './SupportCreateForm'
import { useCallback, useEffect, useRef, useState } from 'react'
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
  const [params, setParams] = useSearchParams()
  const rawTicketId = params.get('ticket')
  const ticketId = rawTicketId && /^[1-9][0-9]*$/.test(rawTicketId) && Number.isSafeInteger(Number(rawTicketId)) ? Number(rawTicketId) : null
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
  const contextOpen = ticketId !== null
  const contextDialog = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    if (contextOpen && !contextDialog.current?.open) contextDialog.current?.showModal()
  }, [contextOpen])

  const refresh = useCallback(async (signal?: AbortSignal, background = false) => {
    if (!background) setLoading(true)
    try {
      const items = await supportTicketsApi.list(filter, signal)
      if (!signal?.aborted) {
        setTickets(items)
        setQueueFailure(null)
      }
    } catch (failure) {
      if (!signal?.aborted && !background) {
        setQueueFailure({
          message: safeSupportMessage(failure, 'queue'),
          diagnostic: safeSupportDiagnostic(failure, 'queue'),
        })
      }
    } finally {
      if (!signal?.aborted && !background) setLoading(false)
    }
  }, [filter])

  useEffect(() => {
    const controller = new AbortController()
    void refresh(controller.signal)
    return () => controller.abort()
  }, [refresh])

  const pollQueue = useCallback((signal: AbortSignal) => refresh(signal, true), [refresh])
  useSupportPolling(pollQueue)

  function openDetail(id: number) {
    setParams((current) => {
      const next = new URLSearchParams(current)
      next.set('ticket', String(id))
      return next
    }, { replace: true })
  }

  useEffect(() => {
    if (ticketId === null) return
    const id = ticketId

    const request = new AbortController()
    setDetail(null)
    setActionFailure(null)
    setDetailLoading(true)
    async function loadDetail() {
      try {
        const value = await supportTicketsApi.detail(id, request.signal)
        if (!request.signal.aborted) setDetail(value)
      } catch (failure) {
        if (request.signal.aborted) return
        setActionFailure({
          message: safeSupportMessage(failure, 'detail'),
          diagnostic: safeSupportDiagnostic(failure, 'detail'),
        })
      } finally {
        if (!request.signal.aborted) setDetailLoading(false)
      }
    }
    void loadDetail()
    return () => request.abort()
  }, [ticketId])

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
      openDetail(claimed.id)
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
      </div>

      <SupportCreateForm onCreated={() => void refresh()} />
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

      {notice && <p role="status" className="support-notice">{notice}</p>}
      {queueFailure && <>
        <div className="support-error" role="alert">{queueFailure.message}<button onClick={() => void refresh()} type="button">Reintentar</button></div>
        <SupportDiagnosticPanel diagnostic={queueFailure.diagnostic} id="support-queue-diagnostic" />
      </>}
      {actionFailure && !contextOpen && <>
        <div className="support-error" role="alert">{actionFailure.message}</div>
        <SupportDiagnosticPanel diagnostic={actionFailure.diagnostic} id="support-action-diagnostic" />
      </>}
      {loading && <p aria-live="polite" className="support-loading">Cargando tickets…</p>}
      {!loading && !queueFailure && tickets.length === 0 && <div className="support-empty"><h2>No hay tickets en esta vista</h2><p>Prueba otro filtro o actualiza la cola más tarde.</p></div>}

      {(!loading && tickets.length > 0) && (
        <div className="support-content">
          <div aria-label="Tickets de soporte" className="ticket-list" role="list">
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
                    {(mine || ticket.status === 'escalated') && <button className="secondary-button" onClick={() => openDetail(ticket.id)} type="button">Ver contexto</button>}
                  </div>
                </article>
              )
            })}
          </div>
        </div>
      )}

      {contextOpen && <dialog
        aria-labelledby="ticket-context-title"
        className="ticket-detail"
        ref={contextDialog}
        onCancel={(event) => event.preventDefault()}
        onClose={() => {
          setParams((current) => {
            const next = new URLSearchParams(current)
            next.delete('ticket')
            return next
          }, { replace: true })
          setDetail(null)
          setDetailLoading(false)
          setActionFailure(null)
        }}
      >
        <div className="ticket-context-heading">
          <h2 id="ticket-context-title">Contexto del ticket</h2>
          <button className="secondary-button" type="button" onClick={() => contextDialog.current?.close()}>Cerrar contexto</button>
        </div>
        {actionFailure && <>
          <div className="support-error" role="alert">{actionFailure.message}</div>
          <SupportDiagnosticPanel diagnostic={actionFailure.diagnostic} id="support-context-diagnostic" />
        </>}
        {detailLoading && <p role="status">Cargando contexto…</p>}
            {detail && <>
              <p className="eyebrow">TICKET #{detail.id}</p>
              <h2>{detail.subject}</h2>
              <dl className="ticket-detail-meta"><div><dt>Estado</dt><dd>{statusLabels[detail.status]}</dd></div><div><dt>Categoría</dt><dd>{({ general: 'General', account: 'Cuenta', technical: 'Problema técnico', other: 'Otro' } as Record<string, string>)[detail.category] ?? detail.category}</dd></div><div><dt>Creado</dt><dd>{formatDate(detail.created_at)}</dd></div></dl>
              <p className="ticket-description chat-ticket-intro">{detail.description}</p>
              <SupportCasePanel key={detail.id} id={detail.id} onChange={(ticket) => { setDetail((current) => current?.id === ticket.id ? ticket : current); void refresh() }} />
            </>}
      </dialog>}
    </section>
  )
}
