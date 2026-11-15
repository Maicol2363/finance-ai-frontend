import { useState } from 'react'
import type { StaffAuthDiagnostic } from '../../shared/auth/staffSessionCoordinator'

function formatDiagnosticReport(diagnostic: StaffAuthDiagnostic): string {
  return [
    'Informe de diagnóstico de autenticación de FinanciAI',
    `Código del error: ${diagnostic.code}`,
    `Operación: staff.auth.${diagnostic.operation}`,
    `Hora UTC: ${diagnostic.occurredAtUtc}`,
    `Plataforma: ${diagnostic.platform}`,
    `Ubicación de la API: ${diagnostic.apiLocation}`,
    `Id. de solicitud/correlación: ${diagnostic.correlationId ?? 'no_disponible'}`,
    `Motivo: ${diagnostic.reason}`,
    'Privacidad: el informe excluye credenciales, cookies, tokens, respuestas del servidor y detalles técnicos sin filtrar.',
  ].join('\n')
}

export function AuthDiagnosticPanel({ diagnostic }: { diagnostic: StaffAuthDiagnostic }) {
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
    <section aria-labelledby="staff-auth-diagnostic-heading" className="diagnostic-panel" data-testid="staff-auth-diagnostic">
      <h2 id="staff-auth-diagnostic-heading">Diagnóstico de autenticación</h2>
      <p>Código del error: <code>{diagnostic.code}</code></p>
      <p className="diagnostic-privacy">El informe contiene datos técnicos seguros para soporte y no incluye información de la cuenta.</p>
      <pre aria-label="Contenido del informe de diagnóstico" className="diagnostic-report">{report}</pre>
      <button
        className="diagnostic-copy-button"
        data-testid="staff-auth-diagnostic-copy-button"
        onClick={() => void copyReport()}
        type="button"
      >
        Copiar informe de diagnóstico
      </button>
      <p aria-live="polite" className="diagnostic-copy-status" role="status">{copyStatus}</p>
    </section>
  )
}
