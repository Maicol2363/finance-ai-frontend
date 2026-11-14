import { useState, type FormEvent } from 'react'
import { SupportDiagnosticPanel } from './SupportDiagnosticPanel'
import { supportTicketsApi, safeSupportDiagnostic, type SupportCustomer, type SupportDiagnostic } from './supportTicketsApi'

export function SupportCreateForm({ onCreated }: { onCreated: () => void }) {
  const [identifier, setIdentifier] = useState('')
  const [customer, setCustomer] = useState<SupportCustomer | null>(null)
  const [subject, setSubject] = useState('')
  const [category, setCategory] = useState('general')
  const [description, setDescription] = useState('')
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<SupportDiagnostic | null>(null)
  const [notice, setNotice] = useState('')
  async function lookup(event: FormEvent) {
    event.preventDefault(); setBusy(true); setFailure(null); setCustomer(null); setNotice('')
    try { setCustomer(await supportTicketsApi.lookup(identifier)) }
    catch (error) { setFailure(safeSupportDiagnostic(error, 'lookup')) }
    finally { setBusy(false) }
  }
  async function create(event: FormEvent) {
    event.preventDefault(); setBusy(true); setFailure(null)
    try {
      const result = await supportTicketsApi.create({ customer_identifier: identifier, subject, category, description })
      setNotice(`Ticket #${result.id} creado sin asignar.`); setCustomer(null); setSubject(''); setDescription(''); onCreated()
    } catch (error) { setFailure(safeSupportDiagnostic(error, 'create')) }
    finally { setBusy(false) }
  }
  return <details className="ticket-card"><summary>Crear ticket para un cliente</summary>
    <form onSubmit={(event) => void lookup(event)}><label>Correo exacto o identificador de cuenta<input required maxLength={320} disabled={busy} value={identifier} onChange={(event) => { setIdentifier(event.target.value); setCustomer(null) }} /></label><button className="secondary-button" disabled={busy} type="submit">Verificar cliente</button></form>
    {customer && <><p>Cuenta #{customer.id} · {customer.email} · {customer.is_active ? 'Activa' : 'Inactiva'}</p><form onSubmit={(event) => void create(event)}>
      <label>Asunto<input required maxLength={160} value={subject} onChange={(event) => setSubject(event.target.value)} /></label>
      <label>Categoría<select value={category} onChange={(event) => setCategory(event.target.value)}><option value="general">General</option><option value="account">Cuenta</option><option value="technical">Problema técnico</option><option value="other">Otro</option></select></label>
      <label>Descripción<textarea required maxLength={4000} value={description} onChange={(event) => setDescription(event.target.value)} /></label><button className="primary-button" disabled={busy} type="submit">Crear ticket</button>
    </form></>}
    {failure && <><p role="alert">No se pudo completar la operación. Verifica los datos y tu sesión.</p><SupportDiagnosticPanel diagnostic={failure} id="support-create-diagnostic" /></>}
    <p role="status">{notice}</p>
  </details>
}
