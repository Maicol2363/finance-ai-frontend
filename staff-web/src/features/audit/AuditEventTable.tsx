import { Link } from 'react-router'
import type { AuditEvent, AuditInvestigationEvent } from './auditApi'
import { formatInstant, MATCH_LABELS, outcomeLabel, targetLabel, UNKNOWN_VALUE, zoneLabel } from './auditFormat'

interface AuditEventTableProps {
  caption: string
  events: Array<AuditEvent | AuditInvestigationEvent>
  timeZone: string
  detailSearch: string
  showMatch?: boolean
}

function isInvestigationEvent(event: AuditEvent | AuditInvestigationEvent): event is AuditInvestigationEvent {
  return 'match' in event
}

export function AuditEventTable({ caption, events, timeZone, detailSearch, showMatch = false }: AuditEventTableProps) {
  return (
    <div className="audit-table-wrap">
      <table className="audit-table">
        <caption>{caption}</caption>
        <thead>
          <tr>
            <th scope="col">Fecha y hora · {zoneLabel(timeZone)}</th>
            <th scope="col">Tipo</th>
            <th scope="col">Resultado</th>
            {showMatch && <th scope="col">Relación</th>}
            <th scope="col">Actor</th>
            <th scope="col">Objetivo</th>
            <th scope="col">Correlación</th>
            <th scope="col"><span className="visually-hidden">Detalle</span></th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => (
            <tr key={event.event_id}>
              <td><time dateTime={event.occurred_at}>{formatInstant(event.occurred_at, timeZone)}</time></td>
              <td><code>{event.event_type}</code></td>
              <td><span className={`audit-outcome outcome-${event.outcome}`}>{outcomeLabel(event.outcome)}</span></td>
              {showMatch && <td>{isInvestigationEvent(event) ? MATCH_LABELS[event.match] : ''}</td>}
              <td>{event.actor_id ?? <span className="audit-unknown">{UNKNOWN_VALUE}</span>}</td>
              <td>{targetLabel(event.target_type, event.target_id)}</td>
              <td>{event.correlation_id ? <code>{event.correlation_id}</code> : <span className="audit-unknown">{UNKNOWN_VALUE}</span>}</td>
              <td>
                <Link aria-label={`Ver detalle del evento ${event.event_id}`} className="text-link" to={`/audit/events/${event.event_id}${detailSearch}`}>
                  Detalle
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
