import { useState } from 'react'
import type { AuditDiagnostic } from './auditFormat'

function formatReport(diagnostic: AuditDiagnostic): string {
  return [
    'Informe de diagnóstico de auditoría de FinanciAI',
    `Código del error: ${diagnostic.code}`,
    `Operación: staff.audit.${diagnostic.operation}`,
    `Hora UTC: ${diagnostic.occurredAtUtc}`,
    'Plataforma: web',
    `Id. de solicitud/correlación: ${diagnostic.correlationId ?? 'no_disponible'}`,
    'Privacidad: el informe excluye filtros, identificadores consultados, credenciales y respuestas del servidor.',
  ].join('\n')
}

interface AuditErrorPanelProps {
  message: string
  diagnostic: AuditDiagnostic
  onRetry?: () => void
}

/** A failed query is an error, never an empty result. */
export function AuditErrorPanel({ message, diagnostic, onRetry }: AuditErrorPanelProps) {
  const [copyStatus, setCopyStatus] = useState('')
  const report = formatReport(diagnostic)

  async function copyReport(): Promise<void> {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Portapapeles no disponible')
      await navigator.clipboard.writeText(report)
      setCopyStatus('Se copió el informe de diagnóstico.')
    } catch {
      setCopyStatus('No se puede copiar aquí. Selecciona y copia el informe.')
    }
  }

  return (
    <section className="audit-error" data-testid="audit-error" role="alert">
      <p className="audit-error-message">{message}</p>
      {onRetry && <button className="secondary-button" onClick={onRetry} type="button">Reintentar</button>}
      <details className="audit-diagnostic">
        <summary>Diagnóstico técnico (código {diagnostic.code})</summary>
        <pre aria-label="Contenido del informe de diagnóstico de auditoría" className="diagnostic-report">{report}</pre>
        <button className="diagnostic-copy-button" onClick={() => void copyReport()} type="button">Copiar informe de diagnóstico</button>
        <p aria-live="polite" className="diagnostic-copy-status" role="status">{copyStatus}</p>
      </details>
    </section>
  )
}
