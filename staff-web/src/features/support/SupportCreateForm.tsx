import { SupportAttachmentInput } from './SupportAttachmentInput'
import { encodeAttachment } from './encodeAttachment'
import { useState, type FormEvent } from 'react'
import { SupportDiagnosticPanel } from './SupportDiagnosticPanel'
import { supportTicketsApi, safeSupportDiagnostic, safeSupportMessage, type SupportCustomer, type SupportDiagnostic, type SupportTicketsApiError } from './supportTicketsApi'

export function SupportCreateForm({ onCreated }: { onCreated: () => void }) {
  const [identifier, setIdentifier] = useState('')
  const [customer, setCustomer] = useState<SupportCustomer | null>(null)
  const [subject, setSubject] = useState('')
  const [category, setCategory] = useState('general')
  const [description, setDescription] = useState('')
  const [attachment, setAttachment] = useState<File | null>(null)
  const [errorMessage, setErrorMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<SupportDiagnostic | null>(null)
  const [notice, setNotice] = useState('')
  function handleAttachmentValidation(error: SupportTicketsApiError | null) {
    if (error) {
      setFailure(safeSupportDiagnostic(error, 'create'))
      setErrorMessage(safeSupportMessage(error, 'create'))
    } else if (failure?.code === 'support_attachment_invalid') {
      setFailure(null)
      setErrorMessage('')
    }
  }
  async function lookup(event: FormEvent) {
    event.preventDefault(); setBusy(true); setFailure(null); setCustomer(null); setNotice('')
    try { setCustomer(await supportTicketsApi.lookup(identifier)) }
    catch (error) { setFailure(safeSupportDiagnostic(error, 'lookup')); setErrorMessage('No se pudo verificar el cliente.') }
    finally { setBusy(false) }
  }
  async function create(event: FormEvent) {
    event.preventDefault(); setBusy(true); setFailure(null)
    try {
      const result = await supportTicketsApi.create({ customer_identifier: identifier, subject, category, description, attachment: attachment ? await encodeAttachment(attachment) : undefined })
      setNotice(`Ticket #${result.id} creado sin asignar.`); setCustomer(null); setSubject(''); setDescription(''); setAttachment(null); onCreated()
    } catch (error) { setFailure(safeSupportDiagnostic(error, 'create')); setErrorMessage(safeSupportMessage(error, 'create')) }
    finally { setBusy(false) }
  }
  return <details className="ticket-card"><summary>Crear ticket para un cliente</summary>
    <form onSubmit={(event) => void lookup(event)}><label>Correo exacto o identificador de cuenta<input required maxLength={320} disabled={busy} value={identifier} onChange={(event) => { setIdentifier(event.target.value); setCustomer(null) }} /></label><button className="secondary-button" disabled={busy} type="submit">Verificar cliente</button></form>
    {customer && <><p>Cuenta #{customer.id} · {customer.email} · {customer.is_active ? 'Activa' : 'Inactiva'}</p><form onSubmit={(event) => void create(event)}>
      <label>Asunto<input required maxLength={160} value={subject} onChange={(event) => setSubject(event.target.value)} /></label>
      <label>Categoría<select value={category} onChange={(event) => setCategory(event.target.value)}><option value="general">General</option><option value="account">Cuenta</option><option value="technical">Problema técnico</option><option value="other">Otro</option></select></label>
      <label>Descripción<textarea required maxLength={4000} value={description} onChange={(event) => setDescription(event.target.value)} /></label><SupportAttachmentInput busy={busy} file={attachment} onChange={setAttachment} onValidationError={handleAttachmentValidation} operation="create" /><button className="primary-button" disabled={busy} type="submit">Crear ticket</button>
    </form></>}
    {failure && <><p role="alert">{errorMessage}</p><SupportDiagnosticPanel diagnostic={failure} id="support-create-diagnostic" /></>}
    <p role="status">{notice}</p>
  </details>
}
