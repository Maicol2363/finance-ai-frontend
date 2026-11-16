import { Link } from 'react-router'
import type { AuditEvent, AuditFilterQuery, AuditInvestigationEvent } from './auditApi'
import {
  eventTypeLabel,
  formatInstant,
  MATCH_LABELS,
  originLabel,
  outcomeLabel,
  roleLabel,
  targetLabel,
  UNKNOWN_VALUE,
  zoneLabel,
} from './auditFormat'

interface AuditEventTableProps {
  caption: string
  events: Array<AuditEvent | AuditInvestigationEvent>
  timeZone: string
  detailSearch: string
  /** Builds the event-list link that narrows the current period to one actor or correlation. */
  pivotTo?: (filters: AuditFilterQuery) => string
  showMatch?: boolean
}

function isInvestigationEvent(event: AuditEvent | AuditInvestigationEvent): event is AuditInvestigationEvent {
  return 'match' in event
}

function Unknown() {
  return <span className="audit-unknown">{UNKNOWN_VALUE}</span>
}

export function AuditEventTable({ caption, events, timeZone, detailSearch, pivotTo, showMatch = false }: AuditEventTableProps) {
  return (
    <div className="audit-table-wrap">
      <table className="audit-table">
        <caption>{caption}</caption>
        <thead>
          <tr>
            <th scope="col">Fecha y hora · {zoneLabel(timeZone)}</th>
            <th scope="col">Evento</th>
            <th scope="col">Resultado</th>
            {showMatch && <th scope="col">Relación</th>}
            <th scope="col">Actor</th>
            <th scope="col">Objetivo</th>
            <th scope="col">Correlación</th>
            <th scope="col"><span className="visually-hidden">Detalle</span></th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => {
            const origin = originLabel(event.context)
            return (
              <tr key={event.event_id}>
                <td><time dateTime={event.occurred_at}>{formatInstant(event.occurred_at, timeZone)}</time></td>
                <td>
                  <span className="audit-cell-main">{eventTypeLabel(event.event_type)}</span>
                  <code className="audit-cell-sub">{event.event_type}</code>
                  {origin && <span className="audit-cell-sub">{origin}</span>}
                </td>
                <td><span className={`audit-outcome outcome-${event.outcome}`}>{outcomeLabel(event.outcome)}</span></td>
                {showMatch && <td>{isInvestigationEvent(event) ? MATCH_LABELS[event.match] : ''}</td>}
                <td>
                  {event.actor_id === null ? (
                    <Unknown />
                  ) : pivotTo ? (
                    <Link
                      aria-label={`Filtrar eventos del actor ${event.actor_id}`}
                      className="text-link"
                      title="Ver solo los eventos de este actor"
                      to={pivotTo({ actor_id: event.actor_id })}
                    >
                      {event.actor_id}
                    </Link>
                  ) : (
                    event.actor_id
                  )}
                  {event.actor_id !== null && (
                    <span className="audit-cell-sub">{event.actor_role ? roleLabel(event.actor_role) : 'Rol no registrado'}</span>
                  )}
                </td>
                <td>{targetLabel(event.target_type, event.target_id)}</td>
                <td>
                  {event.correlation_id === null ? (
                    <Unknown />
                  ) : pivotTo ? (
                    <Link
                      aria-label={`Filtrar eventos con la correlación ${event.correlation_id}`}
                      className="text-link audit-code-link"
                      title="Ver solo los eventos de esta correlación"
                      to={pivotTo({ correlation_id: event.correlation_id })}
                    >
                      <code>{event.correlation_id}</code>
                    </Link>
                  ) : (
                    <code>{event.correlation_id}</code>
                  )}
                </td>
                <td>
                  <Link aria-label={`Ver detalle del evento ${event.event_id}`} className="text-link" to={`/audit/events/${event.event_id}${detailSearch}`}>
                    Detalle
                  </Link>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
