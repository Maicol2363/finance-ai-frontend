import { useState, type FormEvent } from 'react'
import { adminApi, type AdminCase, type AdminOperation } from './adminApi'
import { AdminFailureNotice, type AdminFailure } from './AdminFailureNotice'
import { eventLabel, formatDateTime } from './adminFormat'
import { useAdminFailure } from './useAdminFailure'

type Action = 'reply' | 'resolve' | 'return'

interface Props {
  adminId: number
  data: AdminCase
  onChanged: () => void
  onClaim: () => void
  onFinished: (message: string) => void
}

function author(data: AdminCase, adminId: number, authorId: number): string {
  if (authorId === data.customer.id) return 'Cliente'
  if (authorId === adminId) return 'Tú (administrador)'
  return 'Personal'
}

/**
 * Case context and the ADM-05 operations. Reasons are staff-only metadata: the customer sees
 * only the conversation messages and the final resolution summary. Mutations are offered only
 * to the owning administrator; the backend enforces ownership regardless.
 */
export function EscalationCasePanel({ adminId, data, onChanged, onClaim, onFinished }: Props) {
  const toFailure = useAdminFailure()
  const [action, setAction] = useState<Action | null>(null)
  const [text, setText] = useState('')
  const [confirmed, setConfirmed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<AdminFailure | null>(null)

  const owned = data.owned_by_me
  const unclaimed = data.owner_admin_id === null

  function choose(next: Action | null): void {
    setAction(next)
    setText('')
    setConfirmed(false)
    setFailure(null)
  }

  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    const value = text.trim()
    if (!action || busy || value.length === 0 || (action !== 'reply' && !confirmed)) return
    setBusy(true)
    setFailure(null)
    const operation: AdminOperation = action
    try {
      if (action === 'reply') {
        await adminApi.reply(data.ticket.id, value)
        choose(null)
        onChanged()
      } else if (action === 'resolve') {
        await adminApi.resolve(data.ticket.id, value)
        onFinished('Caso resuelto. El cliente puede leer el resumen de resolución.')
      } else {
        const result = await adminApi.returnToSupport(data.ticket.id, value)
        onFinished(
          result.status === 'in_progress'
            ? 'Caso devuelto al agente de origen, que continúa atendiéndolo.'
            : 'El agente de origen ya no está disponible: el caso volvió a la cola de soporte sin asignar.',
        )
      }
    } catch (error) {
      setFailure(toFailure(error, operation))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div data-testid="admin-case">
      <p className="eyebrow">CASO ESCALADO #{data.ticket.id}</p>
      <h3>{data.ticket.subject}</h3>
      <dl className="ticket-detail-meta">
        <div><dt>Categoría</dt><dd>{data.ticket.category}</dd></div>
        <div><dt>Creado</dt><dd>{formatDateTime(data.ticket.created_at)}</dd></div>
        <div><dt>Cliente</dt><dd>{data.customer.email}{data.customer.is_active ? '' : ' (suspendido)'}</dd></div>
      </dl>

      <h4>Motivo de escalamiento <span className="admin-badge">Solo personal</span></h4>
      <p className="ticket-description" data-testid="admin-escalation-reason">{data.escalation_reason ?? 'Sin motivo registrado.'}</p>
      <p className="admin-hint" data-testid="admin-origin-note">
        {data.originating_agent.can_receive_return
          ? 'El agente de origen está activo: si devuelves el caso, volverá a él en atención.'
          : 'El agente de origen ya no está disponible: si devuelves el caso, volverá a la cola sin asignar.'}
      </p>

      <h4>Descripción</h4>
      <p className="ticket-description">{data.ticket.description}</p>

      <h4>Conversación visible para el cliente</h4>
      {data.messages.length === 0 ? <p className="admin-hint">Aún no hay mensajes.</p> : (
        <ol className="admin-thread" data-testid="admin-messages">
          {data.messages.map((message) => (
            <li key={message.id}>
              <strong>{author(data, adminId, message.author_user_id)}</strong>
              <span className="admin-hint"> · {formatDateTime(message.created_at)}</span>
              <p className="ticket-description">{message.body}</p>
            </li>
          ))}
        </ol>
      )}

      <h4>Historial del caso</h4>
      <ol className="admin-thread" data-testid="admin-history">
        {data.history.map((entry) => (
          <li key={entry.id}>
            <strong>{eventLabel(entry.event_type)}</strong>
            <span className="admin-hint"> · {formatDateTime(entry.created_at)}</span>
            {entry.internal_reason && (
              <p className="ticket-description">
                <span className="admin-badge">Solo personal</span> {entry.internal_reason}
              </p>
            )}
          </li>
        ))}
      </ol>

      {unclaimed && (
        <div className="admin-actions">
          <button className="primary-button" onClick={onClaim} type="button">Reclamar este caso</button>
        </div>
      )}
      {!unclaimed && !owned && (
        <p className="admin-hint" data-testid="admin-case-readonly">Este caso pertenece a otro administrador. Solo puedes consultarlo.</p>
      )}

      {owned && action === null && (
        <div className="admin-actions" data-testid="admin-case-actions">
          <button className="secondary-button" onClick={() => choose('reply')} type="button">Responder al cliente</button>
          <button className="secondary-button" onClick={() => choose('resolve')} type="button">Resolver caso</button>
          <button className="secondary-button" onClick={() => choose('return')} type="button">Devolver a soporte</button>
        </div>
      )}

      {owned && action !== null && (
        <form
          aria-label={action === 'reply' ? 'Responder' : action === 'resolve' ? 'Resolver' : 'Devolver'}
          className="admin-confirm"
          onSubmit={(event) => void submit(event)}
        >
          <div className="admin-field">
            <label htmlFor="admin-case-text">
              {action === 'reply' && 'Mensaje para el cliente'}
              {action === 'resolve' && 'Resumen de resolución (obligatorio)'}
              {action === 'return' && 'Motivo de devolución (obligatorio)'}
            </label>
            <textarea id="admin-case-text" maxLength={4000} onChange={(event) => setText(event.currentTarget.value)} required rows={4} value={text} />
            <p className="admin-hint">
              {action === 'reply' && 'El cliente verá este mensaje en la conversación. No es una nota privada.'}
              {action === 'resolve' && 'El cliente verá este resumen cuando abra su caso.'}
              {action === 'return' && 'Solo lo verá el personal autorizado; el cliente no lo ve.'}
            </p>
          </div>
          {action !== 'reply' && (
            <label className="admin-check">
              <input checked={confirmed} onChange={(event) => setConfirmed(event.currentTarget.checked)} type="checkbox" />
              {action === 'resolve'
                ? ' Confirmo que el caso queda resuelto.'
                : ' Confirmo que devuelvo el caso a soporte.'}
            </label>
          )}
          <div className="admin-actions">
            <button
              className="primary-button"
              disabled={busy || text.trim().length === 0 || (action !== 'reply' && !confirmed)}
              type="submit"
            >
              {busy ? 'Enviando…' : action === 'reply' ? 'Enviar respuesta' : action === 'resolve' ? 'Resolver caso' : 'Devolver caso'}
            </button>
            <button className="text-button" disabled={busy} onClick={() => choose(null)} type="button">Cancelar</button>
          </div>
        </form>
      )}
      {failure && <AdminFailureNotice failure={failure} />}
      <p className="privacy-note">
        Este espacio no muestra saldos, movimientos, recibos ni credenciales del cliente, aunque el caso esté escalado.
      </p>
    </div>
  )
}
