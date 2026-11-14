import { useState } from 'react'
import type { SupportDiagnostic } from './supportTicketsApi'

function formatDiagnosticReport(diagnostic: SupportDiagnostic): string {
  return [
    'Informe de diagnóstico de soporte de FinanciAI',
    `Código del error: ${diagnostic.code}`,
    `Operación: staff.support.${diagnostic.operation}`,
    `Hora UTC: ${diagnostic.occurredAtUtc}`,
    `Plataforma: ${diagnostic.platform}`,
    `Ubicación de la API: ${diagnostic.apiLocation}`,
    `Id. de solicitud/correlación: ${diagnostic.correlationId ?? 'no_disponible'}`,
    `Motivo: ${diagnostic.reason}`,
    'Privacidad: el informe excluye credenciales, cookies, tokens, respuestas del servidor y detalles técnicos sin filtrar.',
  ].join('\n')
}

export function SupportDiagnosticPanel({ diagnostic, id }: { diagnostic: SupportDiagnostic; id: string }) {
  const [copyStatus, setCopyStatus] = useState('')
  const report = formatDiagnosticReport(diagnostic)

  async function copyReport(): Promise<void> {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Portapapeles no disponible')
      await navigator.clipboard.writeText(report)
      setCopyStatus('Se copió el informe de diagnóstico.')
    } catch {
      setCopyStatus('No se puede copiar aquí. Selecciona y copia el informe de arriba.')
    }
  }

  return (
    <section aria-labelledby={`${id}-heading`} className="diagnostic-panel" data-testid="support-diagnostic">
      <h2 id={`${id}-heading`}>Diagnóstico de soporte</h2>
      <p>Código del error: <code>{diagnostic.code}</code></p>
      <p className="diagnostic-privacy">El informe contiene datos técnicos seguros y no incluye información del cliente ni del ticket.</p>
      <pre aria-label="Contenido del informe de diagnóstico de soporte" className="diagnostic-report">{report}</pre>
      <button className="diagnostic-copy-button" onClick={() => void copyReport()} type="button">
        Copiar informe de diagnóstico
      </button>
      <p aria-live="polite" className="diagnostic-copy-status" role="status">{copyStatus}</p>
    </section>
  )
}
