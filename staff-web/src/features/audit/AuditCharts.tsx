import { Link } from 'react-router'
import type { AuditDayCount } from './auditApi'

export interface DistributionRow {
  key: string
  label: string
  count: number
  to: string
}

/** Horizontal bars with the label and exact count always visible as text. */
export function DistributionChart({ rows, title }: { rows: DistributionRow[]; title: string }) {
  const max = Math.max(1, ...rows.map((row) => row.count))
  return (
    <figure className="audit-chart" data-testid="audit-distribution-chart">
      <figcaption>{title}</figcaption>
      <ul className="audit-bars">
        {rows.map((row) => (
          <li key={row.key}>
            <Link className="audit-bar-label" to={row.to}>{row.label}</Link>
            <span aria-hidden="true" className="audit-bar-track">
              <span className="audit-bar-fill" style={{ width: `${Math.max(2, (row.count / max) * 100)}%` }} />
            </span>
            <span className="audit-bar-count">{row.count}</span>
          </li>
        ))}
      </ul>
    </figure>
  )
}

/** Daily columns; the full date/count table below is the readable equivalent. */
export function TimelineChart({ days, title }: { days: AuditDayCount[]; title: string }) {
  const max = Math.max(1, ...days.map((day) => day.count))
  const labelEvery = Math.max(1, Math.ceil(days.length / 15))
  return (
    <figure className="audit-chart" data-testid="audit-timeline-chart">
      <figcaption>{title}</figcaption>
      <div aria-hidden="true" className="audit-columns">
        {days.map((day, index) => (
          <div className="audit-column" key={day.date} title={`${day.date}: ${day.count}`}>
            <span className="audit-column-count">{days.length <= 31 ? day.count : ''}</span>
            <span className="audit-column-bar" style={{ height: `${(day.count / max) * 100}%` }} />
            <span className="audit-column-label">{index % labelEvery === 0 ? day.date.slice(5) : ''}</span>
          </div>
        ))}
      </div>
      <details className="audit-chart-data">
        <summary>Ver los datos de la gráfica ({days.length} días)</summary>
        <table className="audit-table compact">
          <caption>Eventos por día</caption>
          <thead><tr><th scope="col">Fecha</th><th scope="col">Eventos</th></tr></thead>
          <tbody>
            {days.map((day) => <tr key={day.date}><td>{day.date}</td><td>{day.count}</td></tr>)}
          </tbody>
        </table>
      </details>
    </figure>
  )
}
