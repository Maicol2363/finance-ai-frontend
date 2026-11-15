import { useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { auditApi, type AuditFilterQuery, type AuditPeriodQuery, type AuditSummary } from './auditApi'
import { DistributionChart, TimelineChart } from './AuditCharts'
import { AuditErrorPanel } from './AuditErrorPanel'
import { AuditFilterForm } from './AuditFilterForm'
import { formatInstant, outcomeLabel, readQuery, toSearchParams, zoneLabel } from './auditFormat'
import { isAbort, useAuditFailure, type AuditFailure } from './useAuditRequest'

export function AuditSummaryPage() {
  const [params, setParams] = useSearchParams()
  const query = useMemo(() => readQuery(params), [params])
  const toFailure = useAuditFailure()
  const [summary, setSummary] = useState<AuditSummary | null>(null)
  const [failure, setFailure] = useState<AuditFailure | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    setSummary(null)
    setFailure(null)
    auditApi.summary(query.period, query.filters, controller.signal)
      .then(setSummary)
      .catch((error: unknown) => {
        if (!controller.signal.aborted && !isAbort(error)) setFailure(toFailure(error, 'summary'))
      })
    return () => controller.abort()
  }, [query, attempt, toFailure])

  function apply(period: AuditPeriodQuery, filters: AuditFilterQuery): void {
    setParams(toSearchParams(period, filters))
  }

  /** The matching AUD-01 list keeps the period and every applicable filter. */
  function listLink(eventType: string, outcome: string): string {
    const filters: AuditFilterQuery = { ...query.filters, event_type: eventType, outcome }
    return `/audit/events?${toSearchParams(query.period, filters).toString()}`
  }

  /** A mapping entry outside the active type/outcome filter is not part of this summary. */
  const excluded = (eventType: string, outcome: string) =>
    Boolean(
      (query.filters.event_type && query.filters.event_type !== eventType) ||
      (query.filters.outcome && query.filters.outcome !== outcome),
    )
  const countFor = (eventType: string, outcome: string) =>
    summary?.by_type.find((row) => row.event_type === eventType && row.outcome === outcome)?.count ?? 0
  const zone = summary?.period.time_zone ?? query.period.time_zone

  return (
    <section aria-labelledby="audit-summary-title" className="audit-section">
      <div className="audit-section-heading">
        <h2 id="audit-summary-title">Resumen de actividad de seguridad</h2>
        <p>
          Conteos calculados por el servidor sobre todo el conjunto filtrado (no sobre una página). Son hechos registrados:
          no clasifican cuentas ni detectan ataques.
        </p>
      </div>
      <AuditFilterForm
        busy={!summary && !failure}
        initialFilters={query.filters}
        initialPeriod={query.period}
        key={params.toString()}
        onSubmit={apply}
        submitLabel="Calcular resumen"
      />
      {failure && <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} onRetry={() => setAttempt((value) => value + 1)} />}
      {!summary && !failure && <p aria-live="polite" className="async-state" role="status">Calculando el resumen…</p>}
      {summary && (
        <div className="audit-summary" data-testid="audit-summary">
          <p className="audit-cutoff">
            Resumen calculado al corte <strong>{formatInstant(summary.cutoff, zone)}</strong> · {zoneLabel(zone)}. Una
            consulta posterior de la lista puede incluir eventos registrados después de este corte.
          </p>
          {summary.coverage === 'no_records' && (
            <p className="audit-warning" role="note">
              El almacén de auditoría no tiene eventos registrados. No es posible afirmar actividad cero; la cobertura
              histórica no está disponible.
            </p>
          )}
          {summary.coverage === 'partial' && summary.earliest_recorded_at && (
            <p className="audit-warning" role="note">
              Los registros disponibles comienzan el {formatInstant(summary.earliest_recorded_at, zone)}. Las fechas
              anteriores del periodo no tienen cobertura: su conteo cero no significa ausencia de actividad.
            </p>
          )}
          <p className="audit-total">
            Total de eventos en el alcance: <strong data-testid="audit-summary-total">{summary.total_events}</strong>
          </p>
          {summary.total_events === 0 && summary.coverage !== 'no_records' && (
            <p className="audit-empty">No se registraron eventos en este periodo con los filtros aplicados.</p>
          )}
          <div className="audit-metrics">
            {summary.metrics.map((metric) => (
              <article className="audit-metric" key={metric.key}>
                <h3>{metric.label}</h3>
                <p className="audit-metric-count" data-testid={`audit-metric-${metric.key}`}>{metric.count}</p>
                <p className="audit-metric-description">{metric.description}</p>
                <ul aria-label={`Tipos y resultados contados en ${metric.label}`} className="audit-mapping">
                  {metric.mapping.flatMap((entry) => entry.outcomes.map((outcome) => (
                    <li key={`${entry.event_type}-${outcome}`}>
                      {excluded(entry.event_type, outcome) ? (
                        <span className="audit-chip is-excluded">
                          <code>{entry.event_type}</code> · {outcomeLabel(outcome)}: fuera del filtro aplicado
                        </span>
                      ) : (
                        <Link className="audit-chip" to={listLink(entry.event_type, outcome)}>
                          <code>{entry.event_type}</code> · {outcomeLabel(outcome)}: {countFor(entry.event_type, outcome)}
                        </Link>
                      )}
                    </li>
                  )))}
                </ul>
              </article>
            ))}
          </div>
          <p className="audit-hint">
            Los inicios de sesión fallidos y las verificaciones MFA fallidas son medidas distintas: no se suman ni
            representan personas o ataques distintos.
          </p>
          {summary.total_events > 0 ? (
            <div className="audit-charts">
              <DistributionChart
                rows={summary.by_type.map((row) => ({
                  key: `${row.event_type}-${row.outcome}`,
                  label: `${row.event_type} · ${outcomeLabel(row.outcome)}`,
                  count: row.count,
                  to: listLink(row.event_type, row.outcome),
                }))}
                title="Distribución por tipo y resultado"
              />
              <TimelineChart days={summary.by_day} title={`Actividad por día · ${zoneLabel(zone)}`} />
            </div>
          ) : (
            <p className="audit-hint">Sin datos para graficar en este alcance.</p>
          )}
        </div>
      )}
    </section>
  )
}
