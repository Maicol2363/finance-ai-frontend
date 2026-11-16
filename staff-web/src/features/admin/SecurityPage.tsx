import { useEffect, useId, useState, type FormEvent } from 'react'
import { StaffAuthApiError, staffAuthApi } from '../../shared/api/staffAuthApi'
import { safeStaffAuthDiagnostic, type StaffAuthDiagnostic } from '../../shared/auth/staffSessionCoordinator'
import { AuthDiagnosticPanel } from '../auth/AuthDiagnosticPanel'

/**
 * SEC-01: single-use recovery codes for a lost authenticator. Codes are shown once, live only
 * in component memory and are cleared when the section closes. The password is re-confirmed
 * by the server before the previous set is replaced.
 */
export function SecurityPage() {
  const [password, setPassword] = useState('')
  const [codes, setCodes] = useState<string[] | null>(null)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [diagnostic, setDiagnostic] = useState<StaffAuthDiagnostic | null>(null)
  const [copyStatus, setCopyStatus] = useState('')
  const id = useId()

  useEffect(() => () => setCodes(null), [])

  async function generate(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (busy || password.length === 0) return
    setBusy(true)
    setMessage('')
    setDiagnostic(null)
    setCopyStatus('')
    try {
      setCodes(await staffAuthApi.issueRecoveryCodes(password))
    } catch (error) {
      setCodes(null)
      setDiagnostic(safeStaffAuthDiagnostic(error, 'mfa_recovery_codes'))
      if (error instanceof StaffAuthApiError && error.code === 'password_confirmation_invalid') {
        setMessage('La contraseña no es correcta.')
      } else if (error instanceof StaffAuthApiError && error.status === 403) {
        setMessage('Tu sesión ya no puede generar códigos. Inicia sesión de nuevo.')
      } else {
        setMessage('No se pudieron generar los códigos. Inténtalo de nuevo.')
      }
    } finally {
      setPassword('')
      setBusy(false)
    }
  }

  async function copy(): Promise<void> {
    if (!codes) return
    try {
      await navigator.clipboard.writeText(codes.join('\n'))
      setCopyStatus('Códigos copiados.')
    } catch {
      setCopyStatus('No se pudo copiar automáticamente. Anótalos de forma segura.')
    }
  }

  return (
    <div className="admin-section" data-testid="admin-security">
      <h2>Códigos de recuperación</h2>
      <p className="admin-intro">
        Si pierdes el dispositivo con tu aplicación de autenticación, un código de recuperación te permite
        configurar uno nuevo. Cada código sirve una sola vez; al generar un conjunto nuevo, el anterior deja de
        funcionar. Si no tienes códigos, otro administrador del sistema puede restablecer tu autenticador
        siguiendo el procedimiento operativo.
      </p>
      <form aria-label="Generar códigos de recuperación" className="admin-form" onSubmit={(event) => void generate(event)}>
        <div className="admin-field">
          <label htmlFor={`${id}-password`}>Confirma tu contraseña</label>
          <input
            autoComplete="current-password"
            id={`${id}-password`}
            onChange={(event) => setPassword(event.currentTarget.value)}
            required
            type="password"
            value={password}
          />
        </div>
        <button className="primary-button" disabled={busy || password.length === 0} type="submit">
          {busy ? 'Generando…' : codes ? 'Generar un conjunto nuevo' : 'Generar códigos'}
        </button>
      </form>
      {message && <p className="admin-field-error" role="alert">{message}</p>}
      {diagnostic && <AuthDiagnosticPanel diagnostic={diagnostic} />}
      {codes && (
        <div className="admin-secret" data-testid="admin-recovery-codes" role="status">
          <h3>Tus códigos de recuperación</h3>
          <p>Guárdalos ahora en un lugar seguro. No se volverán a mostrar.</p>
          <ol className="admin-codes">
            {codes.map((code) => <li key={code}><code>{code}</code></li>)}
          </ol>
          <div className="admin-actions">
            <button className="secondary-button" onClick={() => void copy()} type="button">Copiar códigos</button>
            <button className="text-button" onClick={() => { setCodes(null); setCopyStatus('') }} type="button">Ocultar y descartar</button>
          </div>
          <p aria-live="polite" className="admin-hint">{copyStatus}</p>
        </div>
      )}
    </div>
  )
}
