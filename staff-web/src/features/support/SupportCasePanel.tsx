import { SupportChatFile } from './SupportChatFile'
import { SupportAttachmentInput } from './SupportAttachmentInput'
import { encodeAttachment } from './encodeAttachment'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { SupportDiagnosticPanel } from './SupportDiagnosticPanel'
import { supportTicketsApi, safeSupportDiagnostic, safeSupportMessage, type AttachmentSummary, type SupportConversation, type SupportDiagnostic, type SupportTicketDetail } from './supportTicketsApi'

export function SupportCasePanel({ id, onChange }: { id: number; onChange: (ticket: SupportTicketDetail) => void }) {
  const [data, setData] = useState<SupportConversation | null>(null)
  const [body, setBody] = useState('')
  const [attachment, setAttachment] = useState<File | null>(null)
  const [errorMessage, setErrorMessage] = useState('')
  const [summary, setSummary] = useState('')
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<SupportDiagnostic | null>(null)
  const [notice, setNotice] = useState('')
  const [transition, setTransition] = useState<'resolve' | 'escalate'>('resolve')
  const scroll = useRef<HTMLDivElement>(null)
  const scrollToLatest = useRef(true)
  useEffect(() => {
    if (scrollToLatest.current && scroll.current && data) {
      scroll.current.scrollTop = scroll.current.scrollHeight
      scrollToLatest.current = false
    }
  }, [data])
  async function load() {
    try { setData(await supportTicketsApi.conversation(id)); setFailure(null) }
    catch (error) { setFailure(safeSupportDiagnostic(error, 'conversation')); setErrorMessage('No se pudo cargar la conversación.') }
  }
  useEffect(() => {
    const controller = new AbortController()
    setData(null); setFailure(null); setBody(''); setSummary(''); setNotice('')
    supportTicketsApi.conversation(id, controller.signal).then((value) => {
      if (!controller.signal.aborted) setData(value)
    }).catch((error: unknown) => {
      if (!controller.signal.aborted) { setFailure(safeSupportDiagnostic(error, 'conversation')); setErrorMessage('No se pudo cargar la conversación.') }
    })
    return () => controller.abort()
  }, [id])
  async function action(kind: 'message' | 'escalate' | 'resolve', event: FormEvent) {
    event.preventDefault(); setBusy(true); setFailure(null); setNotice('')
    try {
      await supportTicketsApi.action(id, kind, kind === 'message' ? { body, attachment: attachment ? await encodeAttachment(attachment) : undefined } : { summary })
      if (kind === 'message') { setBody(''); setAttachment(null); scrollToLatest.current = true }
       setSummary(''); setNotice('Cambio guardado.'); const refreshed = await supportTicketsApi.conversation(id); setData(refreshed); onChange(refreshed.ticket)
    } catch (error) { await load(); setFailure(safeSupportDiagnostic(error, kind)); setErrorMessage(safeSupportMessage(error, kind)) }
    finally { setBusy(false) }
  }
  async function download(file: AttachmentSummary) {
    setBusy(true)
    setFailure(null)
    try {
      const { content } = await supportTicketsApi.download(id, file.id)
      const bytes = Uint8Array.from(atob(content), character => character.charCodeAt(0))
      const url = URL.createObjectURL(new Blob([bytes], { type: 'application/octet-stream' }))
      const link = document.createElement('a')
      link.href = url
      link.download = file.name
      link.click()
      window.setTimeout(() => URL.revokeObjectURL(url), 1000)
    } catch (error) {
      setFailure(safeSupportDiagnostic(error, 'attachment'))
      setErrorMessage(safeSupportMessage(error, 'attachment'))
    } finally {
      setBusy(false)
    }
  }
  function filesFor(messageId: number | null) {
    return data?.attachments?.filter(file => file.message_id === messageId).map(file =>
      <SupportChatFile key={file.id} ticketId={id} file={file} busy={busy} onDownload={(value) => void download(value)} />
    )
  }
  return <div className="support-case">
    <div className="chat-toolbar">
      <h3>Conversación</h3>
      <button className="secondary-button" disabled={busy} onClick={() => void load()} type="button">Actualizar conversación</button>
    </div>
    {failure && <div className="chat-error"><p role="alert">{errorMessage}</p><SupportDiagnosticPanel diagnostic={failure} id="support-case-diagnostic" /></div>}
    <p className="chat-notice" role="status">{notice}</p>
    {!data && !failure && <p className="chat-notice">Cargando conversación…</p>}
    {data && <>
      <details className="chat-info">
        <summary>Cliente e historial</summary>
        <dl className="ticket-detail-meta">
          <div><dt>Identificador de cuenta</dt><dd>{data.customer.id}</dd></div>
          <div><dt>Correo electrónico</dt><dd>{data.customer.email}</dd></div>
          <div><dt>Estado de cuenta</dt><dd>{data.customer.is_active ? 'Activa' : 'Inactiva'}</dd></div>
        </dl>
        <ol>{data.history.map((item) => <li key={item.id}>
          {({ ticket_created: 'Creado', ticket_claimed: 'Reclamado', message_sent: 'Mensaje enviado', ticket_escalated: 'Escalado', ticket_resolved: 'Resuelto' } as Record<string, string>)[item.event_type] ?? 'Actividad'}
          {' · '}{new Date(item.created_at).toLocaleString('es-CO')}
          {item.internal_reason && <p className="ticket-description">Motivo interno: {item.internal_reason}</p>}
        </li>)}</ol>
      </details>
      <div className="chat-scroll" ref={scroll}>
        {data.attachments?.some(file => file.message_id === null) && <div className="chat-initial">
          <strong>Adjunto de la solicitud</strong>
          {filesFor(null)}
        </div>}
        {data.messages.length === 0 && <p className="chat-notice">Aún no hay mensajes.</p>}
        <ol className="chat-messages">
          {data.messages.map((message) => {
            const customer = message.author_user_id === data.customer.id
            return <li key={message.id} className={customer ? 'chat-bubble' : 'chat-bubble chat-outgoing'}>
              <strong>{customer ? 'Cliente' : 'Soporte'}</strong>
              <p className="ticket-description">{message.body}</p>
              {filesFor(message.id)}
              <time dateTime={message.created_at}>{new Date(message.created_at).toLocaleString('es-CO', {dateStyle: 'short', timeStyle: 'short'})}</time>
            </li>
          })}
        </ol>
        {data.ticket.resolution_summary && <div className="chat-initial"><strong>Resolución</strong><p className="ticket-description">{data.ticket.resolution_summary}</p></div>}
      </div>
      {data.ticket.status === 'in_progress' ? <>
        <form className="chat-compose" onSubmit={(event) => void action('message', event)}>
          <SupportAttachmentInput compact busy={busy} file={attachment} onChange={setAttachment} />
          <textarea aria-label="Mensaje al cliente" placeholder="Escribe un mensaje" rows={1} required maxLength={4000} value={body} onChange={(event) => setBody(event.target.value)} />
          <button className="primary-button chat-icon" aria-label="Enviar mensaje" title="Enviar mensaje" disabled={busy || !body.trim()} type="submit">
            <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="m22 2-7 20-4-9-9-4 20-7ZM11 13 22 2"/></svg>
          </button>
        </form>
        <details className="chat-info chat-operations">
          <summary>Gestionar ticket</summary>
          <form onSubmit={(event) => void action(transition, event)}>
            <label>Acción<select value={transition} onChange={(event) => setTransition(event.target.value === 'escalate' ? 'escalate' : 'resolve')}>
              <option value="resolve">Resolver</option>
              <option value="escalate">Escalar</option>
            </select></label>
            <label>{transition === 'resolve' ? 'Resumen de resolución' : 'Motivo interno de escalamiento'}
              <textarea required rows={2} maxLength={4000} value={summary} onChange={(event) => setSummary(event.target.value)} />
            </label>
            <button className="secondary-button" disabled={busy || !summary.trim()} type="submit">
              {transition === 'resolve' ? 'Resolver ticket' : 'Escalar ticket'}
            </button>
          </form>
        </details>
      </> : <p className="chat-notice">Este ticket está en modo de solo lectura.</p>}
    </>}
  </div>
}
