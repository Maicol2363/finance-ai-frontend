import { useId, useState, type FormEvent } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { adminApi, safeAdminDiagnostic, safeAdminMessage, type AdminAccount } from './adminApi'
import { AdminFailureNotice, type AdminFailure } from './AdminFailureNotice'
import { formatDateTime, looksLikeEmail, parseAccountId, roleLabel, statusLabel } from './adminFormat'

type LookupMode = 'email' | 'id'
type PendingAction = null | 'suspend' | 'reactivate'

const REASON_MAX = 500

/** ADM-01 account lookup and ADM-02 suspension/reactivation of login accounts. */
export function AccountsPage() {
  const { session } = useStaffAuth()
  const [mode, setMode] = useState<LookupMode>('email')
  const [query, setQuery] = useState('')
  const [fieldError, setFieldError] = useState('')
  const [searching, setSearching] = useState(false)
  const [account, setAccount] = useState<AdminAccount | null>(null)
  const [failure, setFailure] = useState<AdminFailure | null>(null)
  const [notice, setNotice] = useState('')
  const [panel, setPanel] = useState<PendingAction>(null)
  const [reason, setReason] = useState('')
  const [confirmed, setConfirmed] = useState(false)
  const [busy, setBusy] = useState(false)
  const fieldId = useId()

  function resetPanel(): void {
    setPanel(null)
    setReason('')
    setConfirmed(false)
  }

  async function search(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (searching) return
    setFieldError('')
    setNotice('')
    setFailure(null)
    resetPanel()

    let lookup: () => Promise<AdminAccount>
    if (mode === 'email') {
      if (!looksLikeEmail(query)) {
        setFieldError('Ingresa un correo electrónico completo.')
        return
      }
      const email = query.trim()
      lookup = () => adminApi.lookupByEmail(email)
    } else {
      const id = parseAccountId(query)
      if (id === null) {
        setFieldError('Ingresa un ID de cuenta numérico válido.')
        return
      }
      lookup = () => adminApi.lookupById(id)
    }

    setSearching(true)
    setAccount(null)
    try {
      setAccount(await lookup())
    } catch (error) {
      setFailure({ message: safeAdminMessage(error), diagnostic: safeAdminDiagnostic(error, 'lookup') })
    } finally {
      setSearching(false)
    }
  }

  async function applyAction(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (!account || !panel || busy || !confirmed) return
    if (panel === 'suspend' && reason.trim().length === 0) return
    setBusy(true)
    setFailure(null)
    try {
      const updated = panel === 'suspend'
        ? await adminApi.suspend(account.id, reason.trim())
        : await adminApi.reactivate(account.id)
      setAccount(updated)
      setNotice(
        panel === 'suspend'
          ? 'Cuenta suspendida. Sus sesiones se cerraron y no podrá usar la aplicación hasta que la reactives.'
          : 'Cuenta reactivada. La persona deberá iniciar sesión de nuevo; las sesiones anteriores no se restauran.',
      )
      resetPanel()
    } catch (error) {
      setFailure({
        message: safeAdminMessage(error),
        diagnostic: safeAdminDiagnostic(error, panel === 'suspend' ? 'suspend' : 'reactivate'),
      })
    } finally {
      setBusy(false)
    }
  }

  const isOwnAccount = account !== null && session?.user.id === account.id
  const canSubmit = confirmed && !busy && (panel !== 'suspend' || reason.trim().length > 0)

  return (
    <div className="admin-section" data-testid="admin-accounts">
      <h2>Buscar una cuenta de acceso</h2>
      <p className="admin-intro">
        Busca por correo exacto o por ID de cuenta. Solo verás datos de la cuenta de acceso; nunca saldos,
        movimientos, recibos ni credenciales.
      </p>
      <form aria-label="Buscar cuenta" className="admin-form" noValidate onSubmit={(event) => void search(event)}>
        <fieldset className="admin-radio-group">
          <legend>Buscar por</legend>
          <label><input checked={mode === 'email'} name="lookup-mode" onChange={() => { setMode('email'); setQuery(''); setFieldError('') }} type="radio" value="email" /> Correo electrónico</label>
          <label><input checked={mode === 'id'} name="lookup-mode" onChange={() => { setMode('id'); setQuery(''); setFieldError('') }} type="radio" value="id" /> ID de cuenta</label>
        </fieldset>
        <div className="admin-field">
          <label htmlFor={fieldId}>{mode === 'email' ? 'Correo electrónico exacto' : 'ID de cuenta'}</label>
          <input
            aria-describedby={fieldError ? `${fieldId}-error` : undefined}
            aria-invalid={fieldError ? true : undefined}
            autoComplete="off"
            id={fieldId}
            inputMode={mode === 'id' ? 'numeric' : 'email'}
            maxLength={320}
            onChange={(event) => setQuery(event.currentTarget.value)}
            value={query}
          />
          {fieldError && <p className="admin-field-error" id={`${fieldId}-error`} role="alert">{fieldError}</p>}
        </div>
        <button className="primary-button" disabled={searching} type="submit">{searching ? 'Buscando…' : 'Buscar cuenta'}</button>
      </form>

      <p aria-live="polite" className="admin-notice" data-testid="admin-accounts-notice">{notice}</p>
      {failure && <AdminFailureNotice failure={failure} />}

      {account && (
        <section aria-labelledby="account-result-title" className="admin-card" data-testid="admin-account-result">
          <p className="eyebrow">CUENTA DE ACCESO</p>
          <h3 id="account-result-title">{account.email}</h3>
          <p className="admin-hint">Esta es una cuenta de acceso (login), no una cuenta financiera de la persona.</p>
          <dl className="admin-definition">
            <div><dt>ID</dt><dd>{account.id}</dd></div>
            <div><dt>Rol</dt><dd>{roleLabel(account.role)}</dd></div>
            <div><dt>Estado</dt><dd><span className={`admin-badge status-${account.status}`}>{statusLabel(account.status)}</span></dd></div>
            <div><dt>Registro</dt><dd>{formatDateTime(account.registered_at)}</dd></div>
          </dl>
          {account.suspension && (
            <div className="admin-suspension" data-testid="admin-suspension-detail">
              <h4>Suspensión vigente</h4>
              <p>Motivo: {account.suspension.reason}</p>
              <p className="admin-hint">
                Desde {formatDateTime(account.suspension.suspended_at)} · administrador n.º {account.suspension.suspended_by_user_id}
              </p>
            </div>
          )}

          {isOwnAccount ? (
            <p className="admin-hint" data-testid="admin-own-account">No puedes suspender tu propia cuenta.</p>
          ) : panel === null ? (
            <div className="admin-actions">
              {account.status === 'active' ? (
                <button className="secondary-button admin-danger" onClick={() => setPanel('suspend')} type="button">Suspender cuenta</button>
              ) : (
                <button className="secondary-button" onClick={() => setPanel('reactivate')} type="button">Reactivar cuenta</button>
              )}
            </div>
          ) : (
            <form
              aria-label={panel === 'suspend' ? 'Confirmar suspensión' : 'Confirmar reactivación'}
              className="admin-confirm"
              data-testid="admin-confirm-panel"
              onSubmit={(event) => void applyAction(event)}
            >
              <h4>{panel === 'suspend' ? 'Suspender esta cuenta' : 'Reactivar esta cuenta'}</h4>
              {panel === 'suspend' && (
                <div className="admin-field">
                  <label htmlFor={`${fieldId}-reason`}>Motivo de la suspensión (obligatorio)</label>
                  <textarea
                    id={`${fieldId}-reason`}
                    maxLength={REASON_MAX}
                    onChange={(event) => setReason(event.currentTarget.value)}
                    required
                    rows={3}
                    value={reason}
                  />
                  <p className="admin-hint">{reason.length}/{REASON_MAX} caracteres. El motivo queda visible solo para el personal.</p>
                </div>
              )}
              <label className="admin-check">
                <input checked={confirmed} onChange={(event) => setConfirmed(event.currentTarget.checked)} type="checkbox" />
                {panel === 'suspend'
                  ? ' Entiendo que se cerrarán todas sus sesiones y no podrá usar la aplicación ni el soporte hasta reactivarla.'
                  : ' Entiendo que la persona deberá iniciar sesión de nuevo y completar la verificación que corresponda.'}
              </label>
              <div className="admin-actions">
                <button className="primary-button" disabled={!canSubmit} type="submit">
                  {busy ? 'Aplicando…' : panel === 'suspend' ? 'Confirmar suspensión' : 'Confirmar reactivación'}
                </button>
                <button className="text-button" disabled={busy} onClick={resetPanel} type="button">Cancelar</button>
              </div>
            </form>
          )}
        </section>
      )}
    </div>
  )
}
