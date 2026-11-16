import { useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { StaffAuthApiError, staffAuthApi } from '../../shared/api/staffAuthApi'
import { safeStaffAuthDiagnostic, type StaffAuthDiagnostic } from '../../shared/auth/staffSessionCoordinator'
import { AuthDiagnosticPanel } from './AuthDiagnosticPanel'
import { ThemeToggleButton } from '../../shared/theme/ThemeToggleButton'
import { readActivationToken } from './activationToken'

const MIN_PASSWORD = 8
const MAX_PASSWORD = 128

function activationMessage(error: unknown): string {
  if (error instanceof StaffAuthApiError) {
    if (error.code === 'activation_invalid') {
      return 'Este enlace no es válido, venció o ya se usó. Pide a un administrador una invitación nueva.'
    }
    if (error.code === 'activation_password_invalid') {
      return 'Esa contraseña no es aceptable. Usa al menos 8 caracteres, que no sea una contraseña muy común y que coincida con la confirmación.'
    }
    if (error.status === 429 && error.retryAfterSeconds) {
      return `Demasiados intentos. Vuelve a intentarlo en ${error.retryAfterSeconds} segundos.`
    }
    if (error.code === 'network_error' || error.code === 'request_timeout') {
      return 'No se pudo conectar con el servicio. Comprueba tu conexión e inténtalo de nuevo.'
    }
  }
  return 'No se pudo activar la cuenta. Inténtalo de nuevo.'
}

/** ADM-03: the invited person chooses their own password with a single-use link. */
export function ActivatePage() {
  // The fragment is read once and then removed from the address bar and history.
  const [token, setToken] = useState<string | null>(() => readActivationToken(window.location.hash))
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [diagnostic, setDiagnostic] = useState<StaffAuthDiagnostic | null>(null)
  const [done, setDone] = useState(false)

  useEffect(() => {
    // Opening another activation link in the same tab is only a hash change: re-read it, then
    // remove it from the address bar again.
    const consume = (): void => {
      const next = readActivationToken(window.location.hash)
      if (window.location.hash) window.history.replaceState(null, '', window.location.pathname)
      if (next !== null) {
        setToken(next)
        setDone(false)
        setMessage('')
        setDiagnostic(null)
      }
    }
    consume()
    window.addEventListener('hashchange', consume)
    return () => window.removeEventListener('hashchange', consume)
  }, [])

  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (busy || token === null) return
    if (password.length < MIN_PASSWORD || password.length > MAX_PASSWORD) {
      setMessage(`La contraseña debe tener entre ${MIN_PASSWORD} y ${MAX_PASSWORD} caracteres.`)
      return
    }
    if (password !== confirmation) {
      setMessage('La contraseña y su confirmación no coinciden.')
      return
    }
    setBusy(true)
    setMessage('')
    setDiagnostic(null)
    try {
      await staffAuthApi.activate(token, password, confirmation)
      setToken(null)
      setDone(true)
    } catch (error) {
      setMessage(activationMessage(error))
      setDiagnostic(safeStaffAuthDiagnostic(error, 'activate'))
      if (error instanceof StaffAuthApiError && error.code === 'activation_invalid') setToken(null)
    } finally {
      setPassword('')
      setConfirmation('')
      setBusy(false)
    }
  }

  return (
    <div className="auth-screen">
      <header className="auth-topbar">
        <div aria-label="FinanciAI, portal del personal" className="brand">
          <img alt="" aria-hidden="true" className="brand-logo" src="/finance-ai-app-icon.png" />
          <span><strong>FinanciAI</strong><small>Portal del personal</small></span>
        </div>
        <ThemeToggleButton />
      </header>
      <main className="auth-screen-main" id="main-content">
        <section aria-labelledby="activate-heading" className="auth-page" data-testid="staff-activate-page">
          <div className="auth-card">
            <span className="eyebrow">ACTIVAR CUENTA DEL PERSONAL</span>
            <h1 id="activate-heading">{done ? 'Tu cuenta está activa' : 'Elige tu contraseña'}</h1>
            {done ? (
              <>
                <p className="auth-intro" data-testid="staff-activate-success">
                  Ya puedes iniciar sesión con tu correo y la contraseña que elegiste. Si tu rol requiere
                  verificación en dos pasos, la configurarás en tu primer inicio de sesión.
                </p>
                <Link className="primary-button auth-submit" to="/login">Ir a iniciar sesión</Link>
              </>
            ) : token === null ? (
              <>
                <p aria-live="polite" className="auth-message" data-testid="staff-activate-invalid" role="alert">
                  {message || 'Este enlace de activación no es válido o ya se usó. Pide a un administrador una invitación nueva.'}
                </p>
                {diagnostic && <AuthDiagnosticPanel diagnostic={diagnostic} />}
                <Link className="text-link" to="/login">Volver al inicio de sesión</Link>
              </>
            ) : (
              <>
                <p className="auth-intro">
                  Define la contraseña de tu cuenta. Nadie más la conoce: los administradores no pueden verla.
                </p>
                {message && <p aria-live="polite" className="auth-message" data-testid="staff-activate-message" role="alert">{message}</p>}
                {diagnostic && <AuthDiagnosticPanel diagnostic={diagnostic} />}
                <form aria-labelledby="activate-heading" onSubmit={(event) => void submit(event)}>
                  <div className="auth-field">
                    <label htmlFor="activate-password">Contraseña nueva</label>
                    <input
                      autoComplete="new-password"
                      id="activate-password"
                      maxLength={MAX_PASSWORD}
                      onChange={(event) => setPassword(event.currentTarget.value)}
                      required
                      type="password"
                      value={password}
                    />
                  </div>
                  <div className="auth-field">
                    <label htmlFor="activate-confirmation">Confirma la contraseña</label>
                    <input
                      autoComplete="new-password"
                      id="activate-confirmation"
                      maxLength={MAX_PASSWORD}
                      onChange={(event) => setConfirmation(event.currentTarget.value)}
                      required
                      type="password"
                      value={confirmation}
                    />
                  </div>
                  <button className="primary-button auth-submit" disabled={busy} type="submit">
                    {busy ? 'Activando…' : 'Activar cuenta'}
                  </button>
                </form>
              </>
            )}
          </div>
        </section>
      </main>
    </div>
  )
}
