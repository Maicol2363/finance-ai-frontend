import { useEffect, useMemo, useState } from 'react'
import { Link, useParams, useSearchParams } from 'react-router'
import { auditApi, type AuditEvent, type AuditPeriodQuery } from './auditApi'
import { AuditErrorPanel } from './AuditErrorPanel'
import {
  formatInstant,
  isAccountId,
  outcomeLabel,
  readQuery,
  shiftDate,
  TARGET_TYPE_LABELS,
  todayInZone,
  toSearchParams,
  UNKNOWN_VALUE,
  zoneLabel,
} from './auditFormat'
import { isAbort, useAuditFailure, type AuditFailure } from './useAuditRequest'

function Unknown() {
  return <span className="audit-unknown">{UNKNOWN_VALUE}</span>
}

export function AuditEventDetailPage() {
  const { eventId = '' } = useParams()
  const [params] = useSearchParams()
  const { period } = useMemo(() => readQuery(params), [params])
  const toFailure = useAuditFailure()
  const [event, setEvent] = useState<AuditEvent | null>(null)
  const [failure, setFailure] = useState<AuditFailure | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    setEvent(null)
    setFailure(null)
    auditApi.event(eventId, controller.signal)
      .then(setEvent)
      .catch((error: unknown) => {
        if (!controller.signal.aborted && !isAbort(error)) setFailure(toFailure(error, 'event'))
      })
    return () => controller.abort()
  }, [eventId, attempt, toFailure])

  const back = `/audit/events?${params.toString()}`
  const zone = period.time_zone
  // Related queries always cover the event's own day in the reporting zone.
  const eventDay = event ? todayInZone(zone, new Date(event.occurred_at)) : period.end_date
  const listPeriodHoldsEvent = period.start_date <= eventDay && eventDay <= period.end_date
  const investigationPeriod: AuditPeriodQuery = listPeriodHoldsEvent
    ? period
    : { start_date: shiftDate(eventDay, -6), end_date: eventDay, time_zone: zone }
  const correlationPeriod: AuditPeriodQuery = {
    start_date: shiftDate(eventDay, -1),
    end_date: shiftDate(eventDay, 1),
    time_zone: zone,
  }
  const investigate = (accountId: string) =>
    `/audit/investigation?${toSearchParams(investigationPeriod, {}, { account_id: accountId }).toString()}`

  return (
    <section aria-labelledby="audit-detail-title" className="audit-section">
      <Link className="text-link" to={back}>← Volver a la lista de eventos</Link>
      <div className="audit-section-heading">
        <h2 id="audit-detail-title">Detalle del evento</h2>
        <p>Proyección saneada: solo se muestran los campos y el contexto permitidos para auditoría.</p>
      </div>
      {failure && <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} onRetry={() => setAttempt((value) => value + 1)} />}
      {!event && !failure && <p aria-live="polite" className="async-state" role="status">Cargando el evento…</p>}
      {event && (
        <article className="audit-detail" data-testid="audit-event-detail">
          <dl className="audit-detail-list">
            <div><dt>Id. del evento</dt><dd><code>{event.event_id}</code></dd></div>
            <div><dt>Fecha y hora · {zoneLabel(zone)}</dt><dd>{formatInstant(event.occurred_at, zone)}</dd></div>
            <div><dt>Marca de tiempo UTC registrada</dt><dd><code>{event.occurred_at}</code></dd></div>
            <div><dt>Tipo</dt><dd><code>{event.event_type}</code></dd></div>
            <div><dt>Resultado</dt><dd>{outcomeLabel(event.outcome)} (<code>{event.outcome}</code>)</dd></div>
            <div><dt>Actor</dt><dd>{event.actor_id ?? <Unknown />}</dd></div>
            <div>
              <dt>Tipo de objetivo</dt>
              <dd>{event.target_type ? (TARGET_TYPE_LABELS[event.target_type] ?? event.target_type) : <Unknown />}</dd>
            </div>
            <div><dt>Objetivo</dt><dd>{event.target_id ?? <Unknown />}</dd></div>
            <div><dt>Correlación</dt><dd>{event.correlation_id ? <code>{event.correlation_id}</code> : <Unknown />}</dd></div>
          </dl>
          <h3>Contexto permitido</h3>
          {Object.keys(event.context).length === 0 ? (
            <p className="audit-hint">El evento no tiene contexto adicional permitido.</p>
          ) : (
            <dl className="audit-detail-list">
              {Object.entries(event.context).map(([key, value]) => (
                <div key={key}><dt><code>{key}</code></dt><dd>{value}</dd></div>
              ))}
            </dl>
          )}
          <h3>Consultas relacionadas</h3>
          <ul className="audit-related">
            {event.actor_id && isAccountId(event.actor_id) && (
              <li><Link className="text-link" to={investigate(event.actor_id)}>Investigar la actividad del actor {event.actor_id}</Link></li>
            )}
            {event.target_type === 'account' && event.target_id && isAccountId(event.target_id) && (
              <li><Link className="text-link" to={investigate(event.target_id)}>Investigar la cuenta afectada {event.target_id}</Link></li>
            )}
            {event.correlation_id && (
              <li>
                <Link className="text-link" to={`/audit/events?${toSearchParams(correlationPeriod, { correlation_id: event.correlation_id }).toString()}`}>
                  Ver eventos con la misma correlación
                </Link>
              </li>
            )}
          </ul>
          <p className="audit-hint">
            Compartir un identificador de correlación solo indica que los eventos se registraron en la misma solicitud o
            flujo; no prueba que uno haya causado al otro.
          </p>
        </article>
      )}
    </section>
  )
}
