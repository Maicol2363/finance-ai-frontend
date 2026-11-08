import { useState } from 'react'
import { Link } from 'react-router'

const NOT_FOUND_CODE = 'route_not_found'

function createNotFoundDiagnosticReport(occurredAt: Date): string {
  return [
    'Finance AI error report',
    `Error code: ${NOT_FOUND_CODE}`,
    'Operation: route.not_found',
    `Time UTC: ${occurredAt.toISOString()}`,
    'Platform: web',
    'API location: not_applicable',
    'Request/correlation ID: unavailable',
    'Technical reason: unmatched_route',
    'Message: omitted from copied report',
    'Privacy: the current URL, query values, form values, and secrets are excluded.',
  ].join('\n')
}

export function NotFoundPage() {
  const [report] = useState(() => createNotFoundDiagnosticReport(new Date()))
  const [copyStatus, setCopyStatus] = useState('')

  async function copyReport() {
    try {
      if (!navigator.clipboard?.writeText) {
        throw new Error('Clipboard API unavailable')
      }
      await navigator.clipboard.writeText(report)
      setCopyStatus('Diagnostic report copied.')
    } catch {
      setCopyStatus('Copy is unavailable here. Select and copy the report above.')
    }
  }

  return (
    <section className="feature-page">
      <div className="page-heading"><span className="eyebrow">404 · PAGE NOT FOUND</span><h1>That page is not here</h1><p>Use the workspace navigation to open a planned area.</p></div>
      <section aria-labelledby="not-found-diagnostic-heading" className="diagnostic-panel">
        <h2 id="not-found-diagnostic-heading">Troubleshooting report</h2>
        <p>Error code: <code>{NOT_FOUND_CODE}</code></p>
        <p className="diagnostic-privacy">The report excludes this page’s URL and query values.</p>
        <pre aria-label="Diagnostic report" className="diagnostic-report">{report}</pre>
        <button className="diagnostic-copy-button" onClick={copyReport} type="button">
          Copy diagnostic report
        </button>
        <p aria-live="polite" className="diagnostic-copy-status" role="status">{copyStatus}</p>
      </section>
      <Link className="text-link" to="/">Return to overview</Link>
    </section>
  )
}
