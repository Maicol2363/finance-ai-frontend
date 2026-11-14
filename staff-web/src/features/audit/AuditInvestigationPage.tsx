import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router'
import {
  auditApi,
  type AuditInvestigationEvent,
  type AuditInvestigationPage,
  type AuditPeriodQuery,
} from './auditApi'
import { AuditErrorPanel } from './AuditErrorPanel'
import { AuditEventTable } from './AuditEventTable'
import { AuditFilterForm } from './AuditFilterForm'
import { formatInstant, isAccountId, readQuery, toSearchParams, zoneLabel } from './auditFormat'
import { isAbort, useAuditFailure, type AuditFailure } from './useAuditRequest'

const PAGE_SIZE = 50

export function AuditInvestigationPage() {
  const [params, setParams] = useSearchParams()
  const { period } = useMemo(() => readQuery(params), [params])
  const accountId = params.get('account_id')?.trim() ?? ''
  const validAccount = isAccountId(accountId)
  const toFailure = useAuditFailure()
  const [accountInput, setAccountInput] = useState(accountId)
  const [accountError, setAccountError] = useState('')
  const [items, setItems] = useState<AuditInvestigationEvent[]>([])
  const [page, setPage] = useState<AuditInvestigationPage | null>(null)
  const [loading, setLoading] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [failure, setFailure] = useState<AuditFailure | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    setItems([])
    setPage(null)
    setFailure(null)
    if (!validAccount) return
    const controller = new AbortController()
    setLoading(true)
    auditApi.investigate(accountId, period, { limit: PAGE_SIZE }, controller.signal)
      .then((result) => {
        setPage(result)
        setItems(result.items)
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted && !isAbort(error)) setFailure(toFailure(error, 'investigation'))
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false)
      })
    return () => controller.abort()
  }, [accountId, validAccount, period, attempt, toFailure])

  async function loadMore(): Promise<void> {
    if (!page?.next_cursor || loadingMore) return
    setLoadingMore(true)
    try {
      const next = await auditApi.investigate(accountId, period, { cursor: page.next_cursor, limit: PAGE_SIZE })
      setPage(next)
      setItems((current) => [...current, ...next.items])
    } catch (error) {
      setFailure(toFailure(error, 'investigation'))
    } finally {
      setLoadingMore(false)
    }
  }

  function apply(nextPeriod: AuditPeriodQuery): void {
    const candidate = accountInput.trim()
    if (!isAccountId(candidate)) {
      setAccountError('Ingresa un identificador de cuenta numérico.')
      return
    }
    setAccountError('')
    setParams(toSearchParams(nextPeriod, {}, { account_id: candidate }))
  }

  const zone = page?.period.time_zone ?? period.time_zone
  return (
    <section aria-labelledby="audit-investigation-title" className="audit-section">
      <div className="audit-section-heading">
        <h2 id="audit-investigation-title">Investigar actividad de una cuenta</h2>
        <p>
          Reconstruye, de más antiguo a más reciente, los eventos donde el identificador aparece como actor o como cuenta
          afectada. La cuenta no necesita existir ni estar activa hoy.
        </p>
      </div>
      <div className="audit-field audit-account-field">
        <label htmlFor="audit-account-id">Identificador histórico de la cuenta</label>
        <input
          aria-describedby={accountError ? 'audit-account-id-error' : undefined}
          aria-invalid={Boolean(accountError)}
          autoComplete="off"
          id="audit-account-id"
          inputMode="numeric"
          onChange={(event) => setAccountInput(event.currentTarget.value)}
          value={accountInput}
        />
        {accountError && <span className="audit-field-error" id="audit-account-id-error">{accountError}</span>}
      </div>
      <AuditFilterForm
        busy={loading}
        initialPeriod={period}
        key={params.toString()}
        onSubmit={apply}
        showFilters={false}
        submitLabel="Investigar"
      />
      <aside className="audit-note">
        <h3>Cómo leer esta línea de tiempo</h3>
        <p>
          <strong>Hechos registrados:</strong> cada fila es un evento único (sin duplicados aunque la cuenta sea actor y
          afectada a la vez) con sus datos tal como se registraron.
        </p>
        <p>
          <strong>Explicación, no evidencia:</strong> solo se consultan identificadores históricos; no se lee el directorio
          de cuentas. Se muestran los eventos retenidos y disponibles en el periodo, no un historial completo de la
          cuenta. Compartir una correlación no prueba causalidad.
        </p>
      </aside>
      {failure && <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} onRetry={() => setAttempt((value) => value + 1)} />}
      {!validAccount ? (
        <p className="audit-hint">Ingresa un identificador de cuenta y un periodo para iniciar la investigación.</p>
      ) : loading ? (
        <p aria-live="polite" className="async-state" role="status">Reconstruyendo la actividad…</p>
      ) : page && !failure && items.length === 0 ? (
        <div className="audit-empty" data-testid="audit-investigation-empty">
          <h3>Sin eventos registrados para la cuenta {page.account_id}</h3>
          <p>No hay eventos disponibles en este periodo donde la cuenta sea actor o cuenta afectada.</p>
        </div>
      ) : page && items.length > 0 ? (
        <>
          <AuditEventTable
            caption={`Cuenta ${page.account_id}: ${items.length} eventos, de más antiguo a más reciente, en ${zoneLabel(zone)}.`}
            detailSearch={`?${toSearchParams(period, {}).toString()}`}
            events={items}
            showMatch
            timeZone={zone}
          />
          <p className="audit-hint">Consulta estable hasta el corte {formatInstant(page.read_boundary, zone)}.</p>
          {page.next_cursor && (
            <button className="secondary-button" disabled={loadingMore} onClick={() => void loadMore()} type="button">
              {loadingMore ? 'Cargando…' : 'Cargar eventos posteriores'}
            </button>
          )}
        </>
      ) : null}
    </section>
  )
}
