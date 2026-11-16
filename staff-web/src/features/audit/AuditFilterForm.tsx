import { useId, useMemo, useState, type FormEvent, type ReactNode } from 'react'
import type { AuditFilterQuery, AuditPeriodQuery } from './auditApi'
import { useAuditCatalog } from './auditCatalogContext'
import {
  defaultPeriod,
  describedBy,
  eventTypeLabel,
  FIELD_HINTS,
  isTimeZone,
  OUTCOME_LABELS,
  PERIOD_PRESETS,
  presetPeriod,
  roleLabel,
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
  hint: string
  error?: string
  children: ReactNode
}

/**
 * Label, control, help and error stay separate so the accessible name is only the label. The help
 * is always announced with the control and shown under it while the field has focus.
 */
export function Field({ id, label, hint, error, children }: FieldProps) {
  return (
    <div className="audit-field">
      <label htmlFor={id}>{label}</label>
      {children}
      <span className="audit-field-hint" id={`${id}-hint`}>{hint}</span>
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
  const eventTypes = useMemo(
    () => [...catalog.event_types].sort((a, b) => eventTypeLabel(a).localeCompare(eventTypeLabel(b), 'es')),
    [catalog.event_types],
  )
  const presets = PERIOD_PRESETS.filter((preset) => preset.days <= catalog.max_query_days)

  function setFilter(key: keyof AuditFilterQuery, value: string): void {
    setFilters((current) => {
      const next = { ...current }
      if (value) next[key] = value
      else delete next[key]
      return next
    })
  }

  function submitWith(nextPeriod: AuditPeriodQuery): void {
    const cleaned: AuditFilterQuery = {}
    for (const [key, value] of Object.entries(filters) as Array<[keyof AuditFilterQuery, string | undefined]>) {
      const trimmed = value?.trim()
      if (trimmed) cleaned[key] = trimmed
    }
    const nextErrors = {
      ...validatePeriod(nextPeriod, catalog.max_query_days),
      ...(showFilters ? validateFilters(cleaned) : {}),
    }
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length === 0) onSubmit(nextPeriod, showFilters ? cleaned : {})
  }

  function submit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault()
    submitWith(period)
  }

  function applyPreset(days: number): void {
    const next = presetPeriod(days, period.time_zone)
    setPeriod(next)
    submitWith(next)
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
    'aria-describedby': describedBy(id(name), errors[field]),
  })
  const activePreset = presets.find((preset) => {
    const candidate = presetPeriod(preset.days, period.time_zone)
    return candidate.start_date === period.start_date && candidate.end_date === period.end_date
  })

  return (
    <form className="audit-filters" noValidate onSubmit={submit}>
      <fieldset>
        <legend>Periodo (fechas incluidas en la zona horaria elegida)</legend>
        <div aria-label="Periodos rápidos" className="audit-presets" role="group">
          {presets.map((preset) => (
            <button
              aria-pressed={activePreset?.days === preset.days}
              className="audit-preset"
              disabled={busy}
              key={preset.days}
              onClick={() => applyPreset(preset.days)}
              type="button"
            >
              {preset.label}
            </button>
          ))}
        </div>
        <div className="audit-field-grid">
          <Field error={errors.start_date} hint={FIELD_HINTS.start_date} id={id('start')} label="Desde">
            <input
              {...aria('start', 'start_date')}
              id={id('start')}
              onChange={(event) => setPeriod({ ...period, start_date: event.currentTarget.value })}
              required
              type="date"
              value={period.start_date}
            />
          </Field>
          <Field
            error={errors.end_date}
            hint={`${FIELD_HINTS.end_date} Máximo ${catalog.max_query_days} días por consulta.`}
            id={id('end')}
            label="Hasta"
          >
            <input
              {...aria('end', 'end_date')}
              id={id('end')}
              onChange={(event) => setPeriod({ ...period, end_date: event.currentTarget.value })}
              required
              type="date"
              value={period.end_date}
            />
          </Field>
          <Field hint={FIELD_HINTS.time_zone} id={id('zone')} label="Zona horaria">
            <select
              aria-describedby={describedBy(id('zone'))}
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
            <Field error={errors.event_type} hint={FIELD_HINTS.event_type} id={id('type')} label="Tipo de evento">
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
                {eventTypes.map((type) => (
                  <option key={type} value={type}>{`${eventTypeLabel(type)} (${type})`}</option>
                ))}
              </select>
            </Field>
            <Field hint={FIELD_HINTS.outcome} id={id('outcome')} label="Resultado">
              <select
                aria-describedby={describedBy(id('outcome'))}
                id={id('outcome')}
                onChange={(event) => setFilter('outcome', event.currentTarget.value)}
                value={filters.outcome ?? ''}
              >
                <option value="">Todos</option>
                {catalog.outcomes.map((outcome) => <option key={outcome} value={outcome}>{OUTCOME_LABELS[outcome] ?? outcome}</option>)}
              </select>
            </Field>
            {catalog.actor_roles.length > 0 && (
              <Field error={errors.actor_role} hint={FIELD_HINTS.actor_role} id={id('role')} label="Rol del actor">
                <select
                  {...aria('role', 'actor_role')}
                  id={id('role')}
                  onChange={(event) => setFilter('actor_role', event.currentTarget.value)}
                  value={filters.actor_role ?? ''}
                >
                  <option value="">Cualquiera</option>
                  {catalog.actor_roles.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
                </select>
              </Field>
            )}
            <Field error={errors.actor_id} hint={FIELD_HINTS.actor_id} id={id('actor')} label="Actor (id. de cuenta)">
              <input
                {...aria('actor', 'actor_id')}
                autoComplete="off"
                id={id('actor')}
                inputMode="numeric"
                onChange={(event) => setFilter('actor_id', event.currentTarget.value)}
                value={filters.actor_id ?? ''}
              />
            </Field>
            <Field error={errors.target_type} hint={FIELD_HINTS.target_type} id={id('target-type')} label="Tipo de objetivo">
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
            <Field error={errors.target_id} hint={FIELD_HINTS.target_id} id={id('target')} label="Objetivo (identificador)">
              <input
                {...aria('target', 'target_id')}
                autoComplete="off"
                id={id('target')}
                onChange={(event) => setFilter('target_id', event.currentTarget.value)}
                value={filters.target_id ?? ''}
              />
            </Field>
            <Field error={errors.correlation_id} hint={FIELD_HINTS.correlation_id} id={id('correlation')} label="Correlación">
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
