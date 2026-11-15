import { useId, useState, type FormEvent, type ReactNode } from 'react'
import type { AuditFilterQuery, AuditPeriodQuery } from './auditApi'
import { useAuditCatalog } from './auditCatalogContext'
import {
  defaultPeriod,
  isTimeZone,
  OUTCOME_LABELS,
  TARGET_TYPE_LABELS,
  validateFilters,
  validatePeriod,
} from './auditFormat'

interface AuditFilterFormProps {
  initialPeriod: AuditPeriodQuery
  initialFilters?: AuditFilterQuery
  showFilters?: boolean
  submitLabel: string
  busy?: boolean
  onSubmit: (period: AuditPeriodQuery, filters: AuditFilterQuery) => void
}

interface FieldProps {
  id: string
  label: string
  error?: string
  children: ReactNode
}

/** Label, control and error stay separate so the accessible name is only the label. */
function Field({ id, label, error, children }: FieldProps) {
  return (
    <div className="audit-field">
      <label htmlFor={id}>{label}</label>
      {children}
      {error && <span className="audit-field-error" id={`${id}-error`}>{error}</span>}
    </div>
  )
}

export function AuditFilterForm({
  initialPeriod,
  initialFilters = {},
  showFilters = true,
  submitLabel,
  busy = false,
  onSubmit,
}: AuditFilterFormProps) {
  const catalog = useAuditCatalog()
  const prefix = useId()
  const [period, setPeriod] = useState<AuditPeriodQuery>(initialPeriod)
  const [filters, setFilters] = useState<AuditFilterQuery>(initialFilters)
  const [errors, setErrors] = useState<Record<string, string>>({})

  function setFilter(key: keyof AuditFilterQuery, value: string): void {
    setFilters((current) => {
      const next = { ...current }
      if (value) next[key] = value
      else delete next[key]
      return next
    })
  }

  function submit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault()
    const cleaned: AuditFilterQuery = {}
    for (const [key, value] of Object.entries(filters) as Array<[keyof AuditFilterQuery, string | undefined]>) {
      const trimmed = value?.trim()
      if (trimmed) cleaned[key] = trimmed
    }
    const nextErrors = {
      ...validatePeriod(period, catalog.max_query_days),
      ...(showFilters ? validateFilters(cleaned) : {}),
    }
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length === 0) onSubmit(period, showFilters ? cleaned : {})
  }

  function reset(): void {
    const fresh = defaultPeriod(period.time_zone)
    setPeriod(fresh)
    setFilters({})
    setErrors({})
    onSubmit(fresh, {})
  }

  const id = (name: string) => `${prefix}-${name}`
  const aria = (name: string, field: string) => ({
    'aria-invalid': Boolean(errors[field]),
    'aria-describedby': errors[field] ? `${id(name)}-error` : undefined,
  })

  return (
    <form className="audit-filters" noValidate onSubmit={submit}>
      <fieldset>
        <legend>Periodo (fechas incluidas en la zona horaria elegida)</legend>
        <div className="audit-field-grid">
          <Field error={errors.start_date} id={id('start')} label="Desde">
            <input
              {...aria('start', 'start_date')}
              id={id('start')}
              onChange={(event) => setPeriod({ ...period, start_date: event.currentTarget.value })}
              required
              type="date"
              value={period.start_date}
            />
          </Field>
          <Field error={errors.end_date} id={id('end')} label="Hasta">
            <input
              {...aria('end', 'end_date')}
              id={id('end')}
              onChange={(event) => setPeriod({ ...period, end_date: event.currentTarget.value })}
              required
              type="date"
              value={period.end_date}
            />
          </Field>
          <Field id={id('zone')} label="Zona horaria">
            <select
              id={id('zone')}
              onChange={(event) => {
                const zone = event.currentTarget.value
                if (isTimeZone(zone)) setPeriod({ ...period, time_zone: zone })
              }}
              value={period.time_zone}
            >
              {catalog.time_zones.map((zone) => <option key={zone.name} value={zone.name}>{zone.label}</option>)}
            </select>
          </Field>
        </div>
        <p className="audit-hint">
          Máximo {catalog.max_query_days} días por consulta; la fecha final se incluye completa. Este límite no afecta
          la retención de los registros.
        </p>
      </fieldset>
      {showFilters && (
        <fieldset>
          <legend>Filtros</legend>
          <div className="audit-field-grid">
            <Field error={errors.event_type} id={id('type')} label="Tipo de evento">
              <select
                {...aria('type', 'event_type')}
                id={id('type')}
                onChange={(event) => setFilter('event_type', event.currentTarget.value)}
                value={filters.event_type ?? ''}
              >
                <option value="">Todos</option>
                {filters.event_type && !catalog.event_types.includes(filters.event_type) && (
                  <option value={filters.event_type}>{filters.event_type}</option>
                )}
                {catalog.event_types.map((type) => <option key={type} value={type}>{type}</option>)}
              </select>
            </Field>
            <Field id={id('outcome')} label="Resultado">
              <select id={id('outcome')} onChange={(event) => setFilter('outcome', event.currentTarget.value)} value={filters.outcome ?? ''}>
                <option value="">Todos</option>
                {catalog.outcomes.map((outcome) => <option key={outcome} value={outcome}>{OUTCOME_LABELS[outcome] ?? outcome}</option>)}
              </select>
            </Field>
            <Field error={errors.actor_id} id={id('actor')} label="Actor (id. de cuenta)">
              <input
                {...aria('actor', 'actor_id')}
                autoComplete="off"
                id={id('actor')}
                inputMode="numeric"
                onChange={(event) => setFilter('actor_id', event.currentTarget.value)}
                value={filters.actor_id ?? ''}
              />
            </Field>
            <Field error={errors.target_type} id={id('target-type')} label="Tipo de objetivo">
              <select
                {...aria('target-type', 'target_type')}
                id={id('target-type')}
                onChange={(event) => setFilter('target_type', event.currentTarget.value)}
                value={filters.target_type ?? ''}
              >
                <option value="">Cualquiera</option>
                {catalog.target_types.map((type) => <option key={type} value={type}>{TARGET_TYPE_LABELS[type] ?? type}</option>)}
              </select>
            </Field>
            <Field error={errors.target_id} id={id('target')} label="Objetivo (identificador)">
              <input
                {...aria('target', 'target_id')}
                autoComplete="off"
                id={id('target')}
                onChange={(event) => setFilter('target_id', event.currentTarget.value)}
                value={filters.target_id ?? ''}
              />
            </Field>
            <Field error={errors.correlation_id} id={id('correlation')} label="Correlación">
              <input
                {...aria('correlation', 'correlation_id')}
                autoComplete="off"
                id={id('correlation')}
                onChange={(event) => setFilter('correlation_id', event.currentTarget.value)}
                value={filters.correlation_id ?? ''}
              />
            </Field>
          </div>
        </fieldset>
      )}
      <div className="audit-form-actions">
        <button className="primary-button" disabled={busy} type="submit">{submitLabel}</button>
        <button className="secondary-button" disabled={busy} onClick={reset} type="button">Restablecer</button>
      </div>
    </form>
  )
}
