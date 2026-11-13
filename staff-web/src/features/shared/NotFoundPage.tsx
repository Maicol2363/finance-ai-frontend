import { useState } from 'react'
import { Link } from 'react-router'

const NOT_FOUND_CODE = 'route_not_found'

function createNotFoundDiagnosticReport(occurredAt: Date): string {
  return [
    'Informe de errores de FinanciAI',
    `Código de error: ${NOT_FOUND_CODE}`,
    'Operación: route.not_found',
    `Hora UTC: ${occurredAt.toISOString()}`,
    'Plataforma: web',
    'Ubicación de la API: no_aplica',
    'Id. de solicitud/correlación: no_disponible',
    'Motivo técnico: ruta_no_encontrada',
    'Mensaje: omitido del informe copiado',
    'Privacidad: se excluyen la URL actual, los parámetros, los campos y los datos secretos.',
  ].join('\n')
}

export function NotFoundPage() {
  const [report] = useState(() => createNotFoundDiagnosticReport(new Date()))
  const [copyStatus, setCopyStatus] = useState('')

  async function copyReport() {
    try {
      if (!navigator.clipboard?.writeText) {
        throw new Error('La API del portapapeles no está disponible')
      }
      await navigator.clipboard.writeText(report)
      setCopyStatus('Se copió el informe de diagnóstico.')
    } catch {
      setCopyStatus('No se puede copiar aquí. Selecciona y copia el informe de arriba.')
    }
  }

  return (
    <section className="feature-page">
      <div className="page-heading"><span className="eyebrow">404 · PÁGINA NO ENCONTRADA</span><h1>No encontramos esta página</h1><p>Usa la navegación del espacio para abrir una sección disponible.</p></div>
      <section aria-labelledby="not-found-diagnostic-heading" className="diagnostic-panel">
        <h2 id="not-found-diagnostic-heading">Informe de diagnóstico</h2>
        <p>Código de error: <code>{NOT_FOUND_CODE}</code></p>
        <p className="diagnostic-privacy">El informe no incluye la URL ni los parámetros de esta página.</p>
        <pre aria-label="Contenido del informe de diagnóstico" className="diagnostic-report">{report}</pre>
        <button className="diagnostic-copy-button" onClick={copyReport} type="button">
          Copiar informe de diagnóstico
        </button>
        <p aria-live="polite" className="diagnostic-copy-status" role="status">{copyStatus}</p>
      </section>
      <Link className="text-link" to="/">Volver al inicio</Link>
    </section>
  )
}
