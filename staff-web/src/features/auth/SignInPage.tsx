import { useEffect, useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { ThemeToggleButton } from '../../shared/theme/ThemeToggleButton'
import { AuthDiagnosticPanel } from './AuthDiagnosticPanel'

function supportDestination(value: unknown): string {
  if (typeof value === 'string' && (value === '/support' || value.startsWith('/support/'))) return value
  return '/support'
}

export function SignInPage() {
  const { state, login, retry, retryPendingLogout } = useStaffAuth()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [secondsRemaining, setSecondsRemaining] = useState(0)
  const destination = supportDestination((location.state as { from?: unknown } | null)?.from)

  const retryAfterSeconds = state.status === 'recoverable_error' ? state.retryAfterSeconds : undefined
  useEffect(() => {
    if (!retryAfterSeconds) {
      setSecondsRemaining(0)
      return
    }
    setSecondsRemaining(retryAfterSeconds)
    const timerId = window.setInterval(() => {
      setSecondsRemaining((remaining) => Math.max(0, remaining - 1))
    }, 1000)
    return () => window.clearInterval(timerId)
  }, [retryAfterSeconds])

  async function submitCredentials(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (secondsRemaining > 0 || state.status === 'authenticating') return
    await login(email, password)
    setPassword('')
  }

  if (state.status === 'authenticated') return <Navigate to={destination} replace />

  const errorMessage = state.status === 'anonymous' || state.status === 'recoverable_error'
    ? state.message
    : undefined
  const diagnostic = state.status === 'anonymous' || state.status === 'recoverable_error'
    ? state.diagnostic
    : undefined

  return (
    <div className="auth-screen">
      <a className="skip-link" href="#main-content">Saltar al contenido</a>
      <header className="auth-topbar">
        <div aria-label="FinanciAI, portal del personal" className="brand">
          <span aria-hidden="true" className="brand-mark">F</span>
          <span><strong>FinanciAI</strong><small>Portal del personal</small></span>
        </div>
        <ThemeToggleButton />
      </header>
      <main className="auth-screen-main" id="main-content">
        {state.status === 'logout_pending' ? (
          <section aria-live="polite" className="auth-page" data-testid="staff-logout-pending">
            <div className="auth-card error-state">
              <span className="eyebrow">CIERRE DE SESIÓN PENDIENTE</span>
              <h1>Confirma el cierre de sesión</h1>
              <p>{state.message}</p>
              {state.diagnostic && <AuthDiagnosticPanel diagnostic={state.diagnostic} />}
              <button data-testid="staff-logout-retry-button" onClick={() => void retryPendingLogout()} type="button">Reintentar cierre de sesión</button>
            </div>
          </section>
        ) : state.status === 'restoring' || state.status === 'refreshing' ? (
          <div aria-live="polite" className="async-state" data-testid="staff-auth-loading" role="status">Comprobando tu sesión del personal…</div>
        ) : (
          <section className="auth-page" data-testid="staff-sign-in-page">
            <div className="auth-card">
              <span className="eyebrow">ACCESO PARA AGENTES DE SOPORTE</span>
              <h1 id="staff-sign-in-heading">Iniciar sesión en el portal de soporte</h1>
              <p className="auth-intro">Usa tu cuenta del personal para continuar al espacio de Soporte.</p>
              {errorMessage && (
                <p aria-live="polite" className="auth-message" data-testid="staff-auth-message" role="alert">
                  {errorMessage}
                </p>
              )}
              {diagnostic && <AuthDiagnosticPanel diagnostic={diagnostic} />}
              {state.status === 'recoverable_error' && (
                <button className="text-button" data-testid="staff-auth-retry-button" onClick={() => void retry()} type="button">Comprobar sesión de nuevo</button>
              )}
              <form aria-labelledby="staff-sign-in-heading" data-testid="staff-sign-in-form" onSubmit={(event) => void submitCredentials(event)}>
                <div className="auth-field">
                  <label htmlFor="staff-email">Correo electrónico</label>
                  <input
                    autoComplete="username"
                    data-testid="staff-sign-in-email-input"
                    id="staff-email"
                    name="email"
                    onChange={(event) => setEmail(event.currentTarget.value)}
                    required
                    type="email"
                    value={email}
                  />
                </div>
                <div className="auth-field">
                  <label htmlFor="staff-password">Contraseña</label>
                  <input
                    autoComplete="current-password"
                    data-testid="staff-sign-in-password-input"
                    id="staff-password"
                    name="password"
                    onChange={(event) => setPassword(event.currentTarget.value)}
                    required
                    type="password"
                    value={password}
                  />
                </div>
                <button
                  className="primary-button auth-submit"
                  data-testid="staff-sign-in-submit-button"
                  disabled={state.status === 'authenticating' || secondsRemaining > 0}
                  type="submit"
                >
                  {state.status === 'authenticating'
                    ? 'Iniciando sesión…'
                    : secondsRemaining > 0
                      ? `Vuelve a intentarlo en ${secondsRemaining} s`
                      : 'Iniciar sesión'}
                </button>
              </form>
            </div>
          </section>
        )}
      </main>
    </div>
  )
}
