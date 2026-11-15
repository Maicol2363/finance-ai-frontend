import type { AdminDiagnostic } from './adminApi'

export interface AdminFailure {
  message: string
  diagnostic: AdminDiagnostic
}

/** A safe error message with the correlation reference that lets support match server events. */
export function AdminFailureNotice({ failure }: { failure: AdminFailure }) {
  const { diagnostic } = failure
  return (
    <div className="admin-error" data-testid="admin-error" role="alert">
      <p className="admin-error-message">{failure.message}</p>
      <p className="admin-error-reference">
        Código: {diagnostic.code}
        {diagnostic.correlationId ? ` · Referencia: ${diagnostic.correlationId}` : ''}
      </p>
    </div>
  )
}
