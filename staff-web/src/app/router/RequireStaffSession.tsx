import { Link, Navigate, useLocation } from 'react-router'
import type { ReactNode } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

export function RequireStaffSession({ children }: { children: ReactNode }) {
  const { state, retry, retryPendingLogout } = useStaffAuth()
  const location = useLocation()

  if (state.status === 'authenticated' && state.session.user.role === 'support_agent') {
    return children
  }
  if (state.status === 'anonymous') {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }
  if (state.status === 'recoverable_error') {
    return (
      <section aria-live="polite" className="auth-status-panel error-state" data-testid="staff-auth-recoverable-error">
        <h1>Soporte no está disponible temporalmente</h1>
        <p>{state.message}</p>
        <button data-testid="staff-auth-retry-button" onClick={() => void retry()} type="button">Intentar de nuevo</button>
        <Link data-testid="staff-auth-sign-in-link" to="/login">Volver al inicio de sesión</Link>
      </section>
    )
  }
  if (state.status === 'logout_pending') {
    return (
      <section aria-live="polite" className="auth-status-panel error-state" data-testid="staff-logout-pending">
        <h1>Confirma el cierre de sesión</h1>
        <p>{state.message}</p>
        <button data-testid="staff-logout-retry-button" onClick={() => void retryPendingLogout()} type="button">Reintentar cierre de sesión</button>
      </section>
    )
  }

  const statusMessage = state.status === 'authenticating' ? 'Iniciando sesión…' : 'Comprobando tu sesión del personal…'
  return <div aria-live="polite" className="async-state" data-testid="staff-auth-loading" role="status">{statusMessage}</div>
}
