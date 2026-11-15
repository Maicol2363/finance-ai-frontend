import { useState, type FormEvent } from 'react'
import { Link, Navigate } from 'react-router'
import { roleDestination } from '../../shared/auth/roleHome'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { ThemeToggleButton } from '../../shared/theme/ThemeToggleButton'
import { AuthDiagnosticPanel } from './AuthDiagnosticPanel'

type Proof = 'recovery' | 'authenticator'

const RECOVERY_PATTERN = /^[A-Za-z2-7]{4}(?:[\s-]?[A-Za-z2-7]{4}){3}$/
const CODE_PATTERN = /^\d{6}$/

/**
 * SEC-01 recovery and replacement of the authenticator. The server verifies the password plus
 * exactly one proof, then revokes every session and opens a new enrollment challenge; the
 * second-factor screen continues from there. Credentials never leave component memory.
 */
export function RecoverPage() {
  const { state, resetMfa } = useStaffAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [proof, setProof] = useState<Proof>('recovery')
  const [value, setValue] = useState('')
  const [fieldError, setFieldError] = useState('')

  if (state.status === 'authenticated') return <Navigate replace to={roleDestination(state.session.user.role, undefined)} />
  if (state.status === 'mfa_required') return <Navigate replace to="/login" />

  const busy = state.status === 'authenticating'
  const message = state.status === 'anonymous' || state.status === 'recoverable_error' ? state.message : undefined
  const diagnostic = state.status === 'anonymous' || state.status === 'recoverable_error' ? state.diagnostic : undefined

  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (busy) return
    const trimmed = value.trim()
    if (proof === 'recovery' ? !RECOVERY_PATTERN.test(trimmed) : !CODE_PATTERN.test(trimmed)) {
      setFieldError(
        proof === 'recovery'
          ? 'Ingresa el código de recuperación completo (por ejemplo, ABCD-EFGH-IJKL-MNOP).'
          : 'Ingresa el código de 6 dígitos de tu autenticador actual.',
      )
      return
    }
    setFieldError('')
    const submittedPassword = password
    const submittedValue = trimmed
    setPassword('')
    setValue('')
    await resetMfa(
      email,
      submittedPassword,
      proof === 'recovery' ? { recoveryCode: submittedValue } : { code: submittedValue },
    )
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
        <section aria-labelledby="recover-heading" className="auth-page" data-testid="staff-recover-page">
          <div className="auth-card">
            <span className="eyebrow">RECUPERAR AUTENTICADOR</span>
            <h1 id="recover-heading">Configura un autenticador nuevo</h1>
            <p className="auth-intro">
              Verifica tu identidad con tu contraseña y un código de recuperación (si perdiste el dispositivo) o el
              código de tu autenticador actual (si solo quieres reemplazarlo). Al terminar se cerrarán todas tus
              sesiones y configurarás un autenticador nuevo.
            </p>
            {message && <p aria-live="polite" className="auth-message" data-testid="staff-recover-message" role="alert">{message}</p>}
            {diagnostic && <AuthDiagnosticPanel diagnostic={diagnostic} />}
            <form aria-labelledby="recover-heading" noValidate onSubmit={(event) => void submit(event)}>
              <div className="auth-field">
                <label htmlFor="recover-email">Correo electrónico</label>
                <input autoComplete="username" id="recover-email" onChange={(event) => setEmail(event.currentTarget.value)} required type="email" value={email} />
              </div>
              <div className="auth-field">
                <label htmlFor="recover-password">Contraseña</label>
                <input autoComplete="current-password" id="recover-password" onChange={(event) => setPassword(event.currentTarget.value)} required type="password" value={password} />
              </div>
              <fieldset className="admin-radio-group">
                <legend>Con qué verificas tu identidad</legend>
                <label><input checked={proof === 'recovery'} name="recover-proof" onChange={() => { setProof('recovery'); setValue(''); setFieldError('') }} type="radio" value="recovery" /> Código de recuperación</label>
                <label><input checked={proof === 'authenticator'} name="recover-proof" onChange={() => { setProof('authenticator'); setValue(''); setFieldError('') }} type="radio" value="authenticator" /> Código de mi autenticador actual</label>
              </fieldset>
              <div className="auth-field">
                <label htmlFor="recover-value">{proof === 'recovery' ? 'Código de recuperación' : 'Código de 6 dígitos'}</label>
                <input
                  aria-invalid={fieldError ? true : undefined}
                  autoComplete="off"
                  id="recover-value"
                  inputMode={proof === 'recovery' ? 'text' : 'numeric'}
                  maxLength={proof === 'recovery' ? 24 : 6}
                  onChange={(event) => setValue(event.currentTarget.value)}
                  required
                  value={value}
                />
                {fieldError && <p className="admin-field-error" role="alert">{fieldError}</p>}
              </div>
              <button className="primary-button auth-submit" disabled={busy} type="submit">
                {busy ? 'Verificando…' : 'Verificar y continuar'}
              </button>
            </form>
            <p className="auth-intro">
              ¿No tienes códigos ni acceso a tu autenticador? Pide a un administrador del sistema que restablezca
              tu autenticador tras verificar tu identidad por otro canal.
            </p>
            <Link className="text-link" to="/login">Volver al inicio de sesión</Link>
          </div>
        </section>
      </main>
    </div>
  )
}
