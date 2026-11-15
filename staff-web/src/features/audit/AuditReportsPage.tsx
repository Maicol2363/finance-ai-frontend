import { useEffect, useRef, useState } from 'react'
import { auditApi, type AuditFilterQuery, type AuditPeriodQuery } from './auditApi'
import { useAuditCatalog } from './auditCatalogContext'
import { AuditErrorPanel } from './AuditErrorPanel'
import { AuditFilterForm } from './AuditFilterForm'
import { defaultPeriod } from './auditFormat'
import { useAuditFailure, type AuditFailure } from './useAuditRequest'

interface GeneratedReport {
  reportId: string
  eventCount: number
  filename: string
  url: string
}

export function AuditReportsPage() {
  const catalog = useAuditCatalog()
  const toFailure = useAuditFailure()
  const [generating, setGenerating] = useState(false)
  const [report, setReport] = useState<GeneratedReport | null>(null)
  const [failure, setFailure] = useState<AuditFailure | null>(null)
  const urlRef = useRef<string | null>(null)
  const reportController = useRef<AbortController | null>(null)
  const mounted = useRef(false)

  // The PDF exists only as an in-memory object URL that is released when no longer needed.
  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
      reportController.current?.abort()
      reportController.current = null
      if (urlRef.current) URL.revokeObjectURL(urlRef.current)
      urlRef.current = null
    }
  }, [])

  function release(): void {
    if (urlRef.current) URL.revokeObjectURL(urlRef.current)
    urlRef.current = null
  }

  async function generate(period: AuditPeriodQuery, filters: AuditFilterQuery): Promise<void> {
    if (generating) return
    release()
    setReport(null)
    setFailure(null)
    setGenerating(true)
    const controller = new AbortController()
    reportController.current = controller
    try {
      const file = await auditApi.report(period, filters, controller.signal)
      if (!mounted.current || controller.signal.aborted) return
      const url = URL.createObjectURL(file.blob)
      urlRef.current = url
      setReport({ reportId: file.reportId, eventCount: file.eventCount, filename: file.filename, url })
      const anchor = document.createElement('a')
      anchor.href = url
      anchor.download = file.filename
      anchor.rel = 'noopener'
      document.body.append(anchor)
      anchor.click()
      anchor.remove()
    } catch (error) {
      if (mounted.current && !controller.signal.aborted) setFailure(toFailure(error, 'report'))
    } finally {
      if (reportController.current === controller) {
        reportController.current = null
        if (mounted.current && !controller.signal.aborted) setGenerating(false)
      }
    }
  }

  return (
    <section aria-labelledby="audit-reports-title" className="audit-section">
      <div className="audit-section-heading">
        <h2 id="audit-reports-title">Informes PDF de auditoría</h2>
        <p>
          El informe incluye portada y periodo, resumen ejecutivo, estadísticas, gráficas de distribución y línea de tiempo,
          tabla cronológica completa, observaciones factuales deterministas y metadatos.
        </p>
      </div>
      <ul className="audit-rules">
        <li>Todo el informe sale de una única instantánea de la base de datos; se indica su corte.</li>
        <li>Incluye todos los eventos del alcance, hasta {catalog.max_report_events}. Si hay más, se rechaza: nunca se recorta.</li>
        <li>La exportación queda registrada como evidencia antes de entregar el archivo; si no puede registrarse, no se entrega.</li>
        <li>El archivo se genera en memoria y no queda almacenado ni accesible por enlace.</li>
      </ul>
      <AuditFilterForm
        busy={generating}
        initialPeriod={defaultPeriod(catalog.default_time_zone)}
        onSubmit={(period, filters) => void generate(period, filters)}
        submitLabel={generating ? 'Generando informe…' : 'Generar informe PDF'}
      />
      {generating && <p aria-live="polite" className="async-state" role="status">Generando el informe…</p>}
      {failure && <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} />}
      {report && (
        <div aria-live="polite" className="audit-success" data-testid="audit-report-ready" role="status">
          <p>
            Informe <code>{report.reportId}</code> generado con <strong>{report.eventCount}</strong> eventos. La descarga
            comenzó automáticamente.
          </p>
          <a className="secondary-button" download={report.filename} href={report.url}>Descargar de nuevo</a>
        </div>
      )}
    </section>
  )
}
