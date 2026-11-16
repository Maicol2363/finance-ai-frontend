import { useState } from 'react'
import type { AdminDiagnostic } from './adminApi'
import { formatAdminReport } from './adminFormat'

export interface AdminFailure {
  message: string
  diagnostic: AdminDiagnostic
}

/** A safe error message with the correlation reference and a copyable report for support. */
export function AdminFailureNotice({ failure }: { failure: AdminFailure }) {
  const { diagnostic } = failure
  const [copyStatus, setCopyStatus] = useState('')
  const report = formatAdminReport(diagnostic)

  async function copyReport(): Promise<void> {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Portapapeles no disponible')
      await navigator.clipboard.writeText(report)
      setCopyStatus('Se copió el informe de diagnóstico.')
    } catch {
      setCopyStatus('No se puede copiar aquí. Abre «Ver informe» y copia el texto.')
    }
  }

  return (
    <div className="admin-error" data-testid="admin-error" role="alert">
      <p className="admin-error-message">{failure.message}</p>
      <p className="admin-error-reference">
        Código: {diagnostic.code}
        {diagnostic.correlationId ? ` · Referencia: ${diagnostic.correlationId}` : ''}
      </p>
      <div className="admin-error-actions">
        <button className="diagnostic-copy-button" data-testid="admin-error-copy" onClick={() => void copyReport()} type="button">
          Copiar informe de diagnóstico
        </button>
        <span aria-live="polite" className="diagnostic-copy-status" role="status">{copyStatus}</span>
      </div>
      <details>
        <summary>Ver informe</summary>
        <pre aria-label="Contenido del informe de diagnóstico" className="diagnostic-report" data-testid="admin-error-report">{report}</pre>
      </details>
    </div>
  )
}
