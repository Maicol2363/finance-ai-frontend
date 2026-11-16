import { Link, Navigate, useLocation } from 'react-router'
import { useEffect, useRef, type ReactNode } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { AuthDiagnosticPanel } from '../../features/auth/AuthDiagnosticPanel'

/**
 * Protected content is visible only while the session is confirmed. When an already
 * authenticated view has to be re-confirmed (the 30 s revalidation, a returning tab, a renewal)
 * it is hidden and made inert at once, with a loading notice on top, but it stays mounted: a quick
 * revalidation must not discard what the person was typing or one-time secrets held in memory.
 * Any definitive denial or error replaces the view (it is unmounted), as before.
 */
export function RequireStaffSession({ children }: { children: ReactNode }) {
  const { state, retry, retryPendingLogout } = useStaffAuth()
  const location = useLocation()
  const confirmedBefore = useRef(false)
  const lastFocused = useRef<HTMLElement | null>(null)
  const wasHeld = useRef(false)

  const authenticated = state.status === 'authenticated'
  const held = (state.status === 'restoring' || state.status === 'refreshing') && confirmedBefore.current

  useEffect(() => {
    if (authenticated) confirmedBefore.current = true
    else if (!held) confirmedBefore.current = false
  }, [authenticated, held])

  useEffect(() => {
    // Hiding an inert view blurs the field the person was in; give the focus back once confirmed.
    if (authenticated && wasHeld.current && lastFocused.current?.isConnected) {
      lastFocused.current.focus({ preventScroll: true })
    }
    wasHeld.current = held
  }, [authenticated, held])

  if (authenticated || held) {
    return (
      <>
        <div
          aria-hidden={held ? true : undefined}
          className={held ? 'session-view session-view-held' : 'session-view'}
          data-testid="staff-protected-view"
          inert={held}
          onFocus={(event) => { lastFocused.current = event.target as HTMLElement }}
        >
          {children}
        </div>
        {held && (
          <div aria-live="polite" className="async-state session-hold-notice" data-testid="staff-auth-loading" role="status">
            Comprobando tu sesión del personal…
          </div>
        )}
      </>
    )
  }
  if (state.status === 'anonymous' || state.status === 'mfa_required') {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }
  if (state.status === 'recoverable_error') {
    return (
      <section aria-live="polite" className="auth-status-panel error-state" data-testid="staff-auth-recoverable-error">
        <h1>El portal del personal no está disponible temporalmente</h1>
        <p>{state.message}</p>
        {state.diagnostic && <AuthDiagnosticPanel diagnostic={state.diagnostic} />}
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
        {state.diagnostic && <AuthDiagnosticPanel diagnostic={state.diagnostic} />}
        <button data-testid="staff-logout-retry-button" onClick={() => void retryPendingLogout()} type="button">Reintentar cierre de sesión</button>
      </section>
    )
  }

  const statusMessage = state.status === 'authenticating' ? 'Iniciando sesión…' : 'Comprobando tu sesión del personal…'
  return <div aria-live="polite" className="async-state staff-session-recheck" data-testid="staff-auth-loading" role="status">{statusMessage}</div>
}
