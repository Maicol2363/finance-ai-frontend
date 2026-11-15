import { useEffect, useState, type FormEvent } from 'react'
import { SupportDiagnosticPanel } from './SupportDiagnosticPanel'
import { supportTicketsApi, safeSupportDiagnostic, safeSupportMessage, type SupportConversation, type SupportDiagnostic, type SupportTicketDetail } from './supportTicketsApi'

export function SupportCasePanel({ id, onChange }: { id: number; onChange: (ticket: SupportTicketDetail) => void }) {
  const [data, setData] = useState<SupportConversation | null>(null)
  const [body, setBody] = useState('')
  const [summary, setSummary] = useState('')
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<SupportDiagnostic | null>(null)
  const [notice, setNotice] = useState('')
  async function load() {
    try { setData(await supportTicketsApi.conversation(id)); setFailure(null) }
    catch (error) { setFailure(safeSupportDiagnostic(error, 'conversation')) }
  }
  useEffect(() => {
    const controller = new AbortController()
    setData(null); setFailure(null); setBody(''); setSummary(''); setNotice('')
    supportTicketsApi.conversation(id, controller.signal).then((value) => {
      if (!controller.signal.aborted) setData(value)
    }).catch((error: unknown) => {
      if (!controller.signal.aborted) setFailure(safeSupportDiagnostic(error, 'conversation'))
    })
    return () => controller.abort()
  }, [id])
  async function action(kind: 'message' | 'escalate' | 'resolve', event: FormEvent) {
    event.preventDefault(); setBusy(true); setFailure(null); setNotice('')
    try {
      await supportTicketsApi.action(id, kind, kind === 'message' ? { body } : { summary })
      setBody(''); setSummary(''); setNotice('Cambio guardado.'); const refreshed = await supportTicketsApi.conversation(id); setData(refreshed); onChange(refreshed.ticket)
    } catch (error) { await load(); setFailure(safeSupportDiagnostic(error, kind)) }
    finally { setBusy(false) }
  }
  return <div className="support-case">
    <button className="secondary-button" disabled={busy} onClick={() => void load()} type="button">Actualizar conversación</button>
    {failure && <><p role="alert">{safeSupportMessage(null, 'conversation')}</p><SupportDiagnosticPanel diagnostic={failure} id="support-case-diagnostic" /></>}
    <p role="status">{notice}</p>
    {!data && !failure && <p>Cargando conversación…</p>}
    {data && <>
      <h3>Cliente</h3><dl><dt>Identificador de cuenta</dt><dd>{data.customer.id}</dd><dt>Correo electrónico</dt><dd>{data.customer.email}</dd><dt>Estado de cuenta</dt><dd>{data.customer.is_active ? 'Activa' : 'Inactiva'}</dd></dl>
      <h3>Conversación</h3>
      {data.messages.length === 0 && <p>Aún no hay mensajes.</p>}
      <ol>{data.messages.map((message) => <li key={message.id}><strong>Usuario #{message.author_user_id}</strong> · <time>{new Date(message.created_at).toLocaleString('es-CO')}</time><p className="ticket-description">{message.body}</p></li>)}</ol>
      {data.ticket.resolution_summary && <><h3>Resolución</h3><p className="ticket-description">{data.ticket.resolution_summary}</p></>}
      {data.ticket.status === 'in_progress' ? <>
        <form onSubmit={(event) => void action('message', event)}><label>Mensaje al cliente<textarea required maxLength={4000} value={body} onChange={(event) => setBody(event.target.value)} /></label><button className="primary-button" disabled={busy} type="submit">Enviar mensaje</button></form>
        <form onSubmit={(event) => void action('resolve', event)}><label>Resumen de resolución o motivo interno de escalamiento<textarea required maxLength={4000} value={summary} onChange={(event) => setSummary(event.target.value)} /></label><div className="ticket-actions"><button className="primary-button" disabled={busy} type="submit">Resolver ticket</button><button className="secondary-button" disabled={busy || !summary.trim()} onClick={(event) => void action('escalate', event)} type="button">Escalar ticket</button></div></form>
      </> : <p>Este ticket está en modo de solo lectura.</p>}
      <h3>Historial</h3><ol>{data.history.map((item) => <li key={item.id}>{({ ticket_created: 'Creado', ticket_claimed: 'Reclamado', message_sent: 'Mensaje enviado', ticket_escalated: 'Escalado', ticket_resolved: 'Resuelto' } as Record<string, string>)[item.event_type] ?? 'Actividad'} · Usuario #{item.actor_user_id} · {new Date(item.created_at).toLocaleString('es-CO')}{item.new_status && ` · ${item.previous_status ?? 'inicio'} → ${item.new_status}`}{item.new_assignee_user_id && ` · Agente #${item.new_assignee_user_id}`}{item.internal_reason && <p className="ticket-description">Motivo interno: {item.internal_reason}</p>}</li>)}</ol>
    </>}
  </div>
}
