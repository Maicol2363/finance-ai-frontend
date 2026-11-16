import { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router'
import { auditApi, type AuditEvent, type AuditEventPage, type AuditFilterQuery, type AuditPeriodQuery } from './auditApi'
import { useAuditCatalog } from './auditCatalogContext'
import { AuditErrorPanel } from './AuditErrorPanel'
import { AuditEventTable } from './AuditEventTable'
import { AuditFilterForm } from './AuditFilterForm'
import { formatInstant, periodIncludesToday, readQuery, toSearchParams, zoneLabel } from './auditFormat'
import { isAbort, useAuditFailure, type AuditFailure } from './useAuditRequest'

const PAGE_SIZE = 25
/** How often a list whose period includes today checks for events recorded after its cutoff. */
export const NEW_EVENTS_POLL_MS = 30_000

export function AuditEventsPage() {
  const catalog = useAuditCatalog()
  const [params, setParams] = useSearchParams()
  const query = useMemo(() => readQuery(params), [params])
  const toFailure = useAuditFailure()
  const [items, setItems] = useState<AuditEvent[]>([])
  const [page, setPage] = useState<AuditEventPage | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadingMore, setLoadingMore] = useState(false)
  const [failure, setFailure] = useState<AuditFailure | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [newEvents, setNewEvents] = useState(0)
  const paginationController = useRef<AbortController | null>(null)
  const readBoundary = page?.read_boundary ?? null
  const checkLimit = Math.max(1, Math.min(100, catalog.max_page_size))

  useEffect(() => {
    const controller = new AbortController()
    paginationController.current?.abort()
    paginationController.current = null
    setLoading(true)
    setLoadingMore(false)
    setFailure(null)
    setNewEvents(0)
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

  // Notice, never insert: the visible list stays a stable snapshot until the auditor refreshes it.
  useEffect(() => {
    if (readBoundary === null || !periodIncludesToday(query.period)) return undefined
    let controller: AbortController | null = null
    let stopped = false
    const boundary = Date.parse(readBoundary)
    const check = () => {
      if (stopped || document.visibilityState === 'hidden') return
      controller?.abort()
      const current = new AbortController()
      controller = current
      auditApi.events(query.period, query.filters, { limit: checkLimit }, current.signal)
        .then((fresh) => {
          if (!current.signal.aborted) setNewEvents(fresh.items.filter((item) => Date.parse(item.occurred_at) > boundary).length)
        })
        .catch(() => {
          // A failed background check stays silent and stops; the list and its refresh still work.
          stopped = true
        })
    }
    const timer = window.setInterval(check, NEW_EVENTS_POLL_MS)
    return () => {
      window.clearInterval(timer)
      controller?.abort()
    }
  }, [readBoundary, query, checkLimit])

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

  const refresh = () => setAttempt((value) => value + 1)
  const hasFilters = Object.keys(query.filters).length > 0
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
      <div className="audit-toolbar">
        <p aria-live="polite" className="audit-hint">
          {page ? `Actualizado al corte ${formatInstant(page.read_boundary, zone)} · ${zoneLabel(zone)}.` : ''}
        </p>
        <button className="secondary-button" disabled={loading} onClick={refresh} type="button">Actualizar</button>
      </div>
      {newEvents > 0 && (
        <div className="audit-new-events" data-testid="audit-new-events" role="status">
          <span>
            {newEvents >= checkLimit ? `Hay ${checkLimit} o más eventos nuevos` : `Hay ${newEvents} ${newEvents === 1 ? 'evento nuevo' : 'eventos nuevos'}`}{' '}
            desde el corte.
          </span>
          <button className="text-button" onClick={refresh} type="button">Mostrar ahora</button>
        </div>
      )}
      {failure && (
        <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} onRetry={refresh} />
      )}
      {loading ? (
        <p aria-live="polite" className="async-state" role="status">Consultando eventos…</p>
      ) : page && !failure && items.length === 0 ? (
        <div className="audit-empty" data-testid="audit-events-empty">
          <h3>No hay eventos que coincidan</h3>
          <p>
            No se registraron eventos de seguridad en este periodo{hasFilters ? ' con los filtros aplicados' : ''}. Esto no
            indica un error: prueba ampliar el periodo{hasFilters ? ' o quitar filtros' : ''}.
          </p>
          {hasFilters && (
            <button className="secondary-button" onClick={() => apply(query.period, {})} type="button">Quitar filtros</button>
          )}
        </div>
      ) : page && items.length > 0 ? (
        <>
          <AuditEventTable
            caption={`${items.length} eventos cargados. Las horas se muestran en ${zoneLabel(zone)}.`}
            detailSearch={`?${params.toString()}`}
            events={items}
            pivotTo={(filters) => `/audit/events?${toSearchParams(query.period, { ...query.filters, ...filters }).toString()}`}
            timeZone={zone}
          />
          <p className="audit-hint">
            La lista no cambia mientras la revisas; los eventos registrados después del corte aparecen al pulsar
            «Actualizar».
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
