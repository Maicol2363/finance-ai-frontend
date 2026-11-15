import { useEffect, useState, type FormEvent } from 'react'
import type { StaffMfaEnrollmentView } from '../../shared/api/staffAuthApi'
import type { StaffAuthState } from '../../shared/auth/staffSessionCoordinator'
import { AuthDiagnosticPanel } from './AuthDiagnosticPanel'

type MfaState = Extract<StaffAuthState, { status: 'mfa_required' }>

interface MfaStepProps {
  state: MfaState
  startMfaEnrollment: () => Promise<StaffMfaEnrollmentView | null>
  verifyMfa: (code: string) => Promise<void>
  cancelMfa: () => Promise<void>
}

const CODE_PATTERN = /^\d{6}$/

function formatExpiry(value: string): string {
  return new Intl.DateTimeFormat('es-CO', { timeStyle: 'short' }).format(new Date(value))
}

function groupSecret(secret: string): string {
  return secret.match(/.{1,4}/g)?.join(' ') ?? secret
}

export function MfaStep({ state, startMfaEnrollment, verifyMfa, cancelMfa }: MfaStepProps) {
  // The enrollment secret lives only in this component's memory and disappears with it.
  const [enrollment, setEnrollment] = useState<StaffMfaEnrollmentView | null>(null)
  const [code, setCode] = useState('')
  const [secondsRemaining, setSecondsRemaining] = useState(0)
  const needsEnrollment = state.challenge.enrollment_required && enrollment === null

  useEffect(() => {
    if (!state.retryAfterSeconds) {
      setSecondsRemaining(0)
      return
    }
    setSecondsRemaining(state.retryAfterSeconds)
    const timerId = window.setInterval(() => {
      setSecondsRemaining((remaining) => Math.max(0, remaining - 1))
    }, 1000)
    return () => window.clearInterval(timerId)
  }, [state.retryAfterSeconds])

  async function beginEnrollment(): Promise<void> {
    const created = await startMfaEnrollment()
    if (created) setEnrollment(created)
  }

  async function submitCode(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (!CODE_PATTERN.test(code) || state.pending || secondsRemaining > 0) return
    const submitted = code
    setCode('')
    await verifyMfa(submitted)
  }

  return (
    <section aria-labelledby="staff-mfa-heading" className="auth-page" data-testid="staff-mfa-step">
      <div className="auth-card">
        <span className="eyebrow">VERIFICACIÓN EN DOS PASOS</span>
        <h1 id="staff-mfa-heading">
          {state.challenge.enrollment_required ? 'Configura tu autenticador' : 'Ingresa tu código de verificación'}
        </h1>
        <p className="auth-intro">
          Tu contraseña es correcta. Para acceder a funciones privilegiadas necesitas además un código
          de tu aplicación de autenticación.
        </p>
        <p className="audit-hint" data-testid="staff-mfa-expiry">
          Este paso vence: <time dateTime={state.challenge.challenge_expires_at}>{formatExpiry(state.challenge.challenge_expires_at)}</time>
        </p>
        {state.message && (
          <p aria-live="polite" className="auth-message" data-testid="staff-mfa-message" role="alert">{state.message}</p>
        )}
        {state.diagnostic && <AuthDiagnosticPanel diagnostic={state.diagnostic} />}

        {needsEnrollment ? (
          <div className="mfa-enroll-start">
            <p className="auth-intro">
              Aún no tienes un autenticador activo. Genera un código QR y escanéalo con una aplicación compatible
              con TOTP (por ejemplo, Google Authenticator, Microsoft Authenticator o 1Password).
            </p>
            <button
              className="primary-button auth-submit"
              data-testid="staff-mfa-enroll-button"
              disabled={state.pending}
              onClick={() => void beginEnrollment()}
              type="button"
            >
              {state.pending ? 'Generando código QR…' : 'Generar código QR'}
            </button>
          </div>
        ) : (
          <>
            {enrollment && (
              <div className="mfa-enrollment" data-testid="staff-mfa-enrollment">
                <img
                  alt="Código QR para configurar la aplicación de autenticación"
                  className="mfa-qr"
                  height={180}
                  src={enrollment.qr_svg_data_url}
                  width={180}
                />
                <div>
                  <p>Si no puedes escanear el código, ingresa esta clave manualmente:</p>
                  <code aria-label="Clave de configuración" className="mfa-secret">{groupSecret(enrollment.secret)}</code>
                  <p className="mfa-hint">Cuenta: {enrollment.account_name} · Emisor: {enrollment.issuer}. La clave no se volverá a mostrar.</p>
                </div>
              </div>
            )}
            <form aria-labelledby="staff-mfa-heading" data-testid="staff-mfa-form" onSubmit={(event) => void submitCode(event)}>
              <div className="auth-field">
                <label htmlFor="staff-mfa-code">Código de verificación de 6 dígitos</label>
                <input
                  autoComplete="one-time-code"
                  data-testid="staff-mfa-code-input"
                  id="staff-mfa-code"
                  inputMode="numeric"
                  maxLength={6}
                  name="code"
                  onChange={(event) => setCode(event.currentTarget.value.replace(/\D/g, '').slice(0, 6))}
                  pattern="[0-9]{6}"
                  required
                  value={code}
                />
              </div>
              <button
                className="primary-button auth-submit"
                data-testid="staff-mfa-submit-button"
                disabled={state.pending || !CODE_PATTERN.test(code) || secondsRemaining > 0}
                type="submit"
              >
                {state.pending
                  ? 'Verificando…'
                  : secondsRemaining > 0
                    ? `Vuelve a intentarlo en ${secondsRemaining} s`
                    : 'Verificar y entrar'}
              </button>
            </form>
          </>
        )}
        <button className="text-button mfa-cancel" data-testid="staff-mfa-cancel-button" onClick={() => void cancelMfa()} type="button">
          Cancelar y volver al inicio de sesión
        </button>
      </div>
    </section>
  )
}
