import { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router'
import { auditApi, type AuditEvent, type AuditEventPage, type AuditFilterQuery, type AuditPeriodQuery } from './auditApi'
import { AuditErrorPanel } from './AuditErrorPanel'
import { AuditEventTable } from './AuditEventTable'
import { AuditFilterForm } from './AuditFilterForm'
import { formatInstant, readQuery, toSearchParams, zoneLabel } from './auditFormat'
import { isAbort, useAuditFailure, type AuditFailure } from './useAuditRequest'

const PAGE_SIZE = 25

export function AuditEventsPage() {
  const [params, setParams] = useSearchParams()
  const query = useMemo(() => readQuery(params), [params])
  const toFailure = useAuditFailure()
  const [items, setItems] = useState<AuditEvent[]>([])
  const [page, setPage] = useState<AuditEventPage | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [failure, setFailure] = useState<AuditFailure | null>(null)
  const [attempt, setAttempt] = useState(0)
  const paginationController = useRef<AbortController | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    paginationController.current?.abort()
    paginationController.current = null
    setLoading(true)
    setLoadingMore(false)
    setFailure(null)
    setItems([])
    setPage(null)
    auditApi.events(query.period, query.filters, { limit: PAGE_SIZE }, controller.signal)
      .then((result) => {
        setPage(result)
        setItems(result.items)
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted && !isAbort(error)) setFailure(toFailure(error, 'events'))
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false)
      })
    return () => {
      controller.abort()
      paginationController.current?.abort()
      paginationController.current = null
    }
  }, [query, attempt, toFailure])

  async function loadMore(): Promise<void> {
    if (!page?.next_cursor || loadingMore) return
    const controller = new AbortController()
    paginationController.current = controller
    setLoadingMore(true)
    setFailure(null)
    try {
      const next = await auditApi.events(
        query.period,
        query.filters,
        { cursor: page.next_cursor, limit: PAGE_SIZE },
        controller.signal,
      )
      if (controller.signal.aborted) return
      setPage(next)
      setItems((current) => [...current, ...next.items])
    } catch (error) {
      if (!controller.signal.aborted && !isAbort(error)) setFailure(toFailure(error, 'events'))
    } finally {
      if (paginationController.current === controller) {
        paginationController.current = null
        if (!controller.signal.aborted) setLoadingMore(false)
      }
    }
  }

  function apply(period: AuditPeriodQuery, filters: AuditFilterQuery): void {
    setParams(toSearchParams(period, filters))
  }

  const zone = page?.period.time_zone ?? query.period.time_zone
  return (
    <section aria-labelledby="audit-events-title" className="audit-section">
      <div className="audit-section-heading">
        <h2 id="audit-events-title">Eventos de seguridad</h2>
        <p>Lista paginada de todos los eventos de seguridad del sistema, de más reciente a más antiguo.</p>
      </div>
      <AuditFilterForm
        busy={loading}
        initialFilters={query.filters}
        initialPeriod={query.period}
        key={params.toString()}
        onSubmit={apply}
        submitLabel="Aplicar filtros"
      />
      {failure && (
        <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} onRetry={() => setAttempt((value) => value + 1)} />
      )}
      {loading ? (
        <p aria-live="polite" className="async-state" role="status">Consultando eventos…</p>
      ) : page && !failure && items.length === 0 ? (
        <div className="audit-empty" data-testid="audit-events-empty">
          <h3>No hay eventos que coincidan</h3>
          <p>No se registraron eventos de seguridad en este periodo con los filtros aplicados.</p>
        </div>
      ) : page && items.length > 0 ? (
        <>
          <AuditEventTable
            caption={`${items.length} eventos cargados. Las horas se muestran en ${zoneLabel(zone)}.`}
            detailSearch={`?${params.toString()}`}
            events={items}
            timeZone={zone}
          />
          <p className="audit-hint">
            Lista estable hasta el corte {formatInstant(page.read_boundary, zone)}: los eventos registrados después
            aparecerán al volver a consultar.
          </p>
          {page.next_cursor && (
            <button className="secondary-button" disabled={loadingMore} onClick={() => void loadMore()} type="button">
              {loadingMore ? 'Cargando…' : 'Cargar más eventos'}
            </button>
          )}
        </>
      ) : null}
    </section>
  )
}
