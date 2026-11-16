import { useId, useState, type FormEvent } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import {
  adminApi,
  type PortalStaffRole,
  type StaffAccount,
  type StaffInvitationCreated,
} from './adminApi'
import { AdminFailureNotice, type AdminFailure } from './AdminFailureNotice'
import { activationLink, formatDateTime, looksLikeEmail, parseAccountId, roleLabel, statusLabel } from './adminFormat'
import { useAdminFailure } from './useAdminFailure'

const ASSIGNABLE: ReadonlyArray<{ value: PortalStaffRole; label: string }> = [
  { value: 'support_agent', label: 'Agente de soporte' },
  { value: 'security_auditor', label: 'Auditor de seguridad' },
]

/** ADM-03 staff invitations and ADM-04 role changes. Admin grants are not offered here. */
export function StaffPage() {
  return (
    <div className="admin-section" data-testid="admin-staff">
      <InvitationForm />
      <RoleForm />
    </div>
  )
}

function InvitationForm() {
  const toFailure = useAdminFailure()
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<PortalStaffRole>('support_agent')
  const [fieldError, setFieldError] = useState('')
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<AdminFailure | null>(null)
  const [created, setCreated] = useState<StaffInvitationCreated | null>(null)
  const [copyStatus, setCopyStatus] = useState('')
  const id = useId()

  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (busy) return
    setFieldError('')
    setFailure(null)
    setCopyStatus('')
    if (!looksLikeEmail(email)) {
      setFieldError('Ingresa un correo electrónico completo.')
      return
    }
    setBusy(true)
    try {
      setCreated(await adminApi.invite(email.trim(), role))
      setEmail('')
    } catch (error) {
      setCreated(null)
      setFailure(toFailure(error, 'invite'))
    } finally {
      setBusy(false)
    }
  }

  async function copy(link: string): Promise<void> {
    try {
      await navigator.clipboard.writeText(link)
      setCopyStatus('Enlace copiado.')
    } catch {
      setCopyStatus('No se pudo copiar automáticamente. Selecciona el enlace y cópialo.')
    }
  }

  return (
    <section aria-labelledby={`${id}-title`} className="admin-card">
      <h2 id={`${id}-title`}>Invitar a una persona del personal</h2>
      <p className="admin-intro">
        La persona recibirá un enlace de un solo uso con vencimiento y elegirá su propia contraseña. No tendrá
        acceso hasta completar la activación. Los administradores no se crean desde el portal.
      </p>
      <form aria-labelledby={`${id}-title`} className="admin-form" noValidate onSubmit={(event) => void submit(event)}>
        <div className="admin-field">
          <label htmlFor={`${id}-email`}>Correo electrónico</label>
          <input
            aria-invalid={fieldError ? true : undefined}
            autoComplete="off"
            id={`${id}-email`}
            maxLength={320}
            onChange={(event) => setEmail(event.currentTarget.value)}
            type="email"
            value={email}
          />
          {fieldError && <p className="admin-field-error" role="alert">{fieldError}</p>}
        </div>
        <div className="admin-field">
          <label htmlFor={`${id}-role`}>Rol inicial</label>
          <select id={`${id}-role`} onChange={(event) => setRole(event.currentTarget.value as PortalStaffRole)} value={role}>
            {ASSIGNABLE.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
          </select>
        </div>
        <button className="primary-button" disabled={busy} type="submit">{busy ? 'Creando invitación…' : 'Crear invitación'}</button>
      </form>
      {failure && <AdminFailureNotice failure={failure} />}
      {created && (
        <div className="admin-secret" data-testid="admin-invitation-created" role="status">
          <h3>Invitación creada para {created.email}</h3>
          <p>
            Rol: {roleLabel(created.role)} · Vence: {formatDateTime(created.expires_at)}
          </p>
          <label htmlFor={`${id}-link`}>Enlace de activación (se muestra una sola vez)</label>
          <input id={`${id}-link`} onFocus={(event) => event.currentTarget.select()} readOnly value={activationLink(created.activation_token)} />
          <div className="admin-actions">
            <button className="secondary-button" onClick={() => void copy(activationLink(created.activation_token))} type="button">Copiar enlace</button>
            <button
              className="text-button"
              onClick={() => { setCreated(null); setCopyStatus('') }}
              type="button"
            >Ocultar y descartar</button>
          </div>
          <p aria-live="polite" className="admin-hint">{copyStatus}</p>
          <p className="admin-hint">
            Compártelo por un canal seguro. Si se pierde, deberás crear una invitación nueva cuando esta venza.
            No guardamos el enlace ni podemos volver a mostrarlo.
          </p>
        </div>
      )}
    </section>
  )
}

function RoleForm() {
  const { session } = useStaffAuth()
  const toFailure = useAdminFailure()
  const [idText, setIdText] = useState('')
  const [fieldError, setFieldError] = useState('')
  const [loading, setLoading] = useState(false)
  const [staff, setStaff] = useState<StaffAccount | null>(null)
  const [target, setTarget] = useState<PortalStaffRole | ''>('')
  const [confirmed, setConfirmed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<AdminFailure | null>(null)
  const [notice, setNotice] = useState('')
  const id = useId()

  async function load(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (loading) return
    setFieldError('')
    setFailure(null)
    setNotice('')
    const accountId = parseAccountId(idText)
    if (accountId === null) {
      setFieldError('Ingresa un ID de cuenta numérico válido.')
      return
    }
    setLoading(true)
    setStaff(null)
    try {
      const found = await adminApi.staff(accountId)
      setStaff(found)
      setTarget(found.assignable_roles[0] ?? '')
      setConfirmed(false)
    } catch (error) {
      setFailure(toFailure(error, 'staff'))
    } finally {
      setLoading(false)
    }
  }

  async function change(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (!staff || target === '' || !confirmed || busy) return
    setBusy(true)
    setFailure(null)
    try {
      const updated = await adminApi.changeRole(staff.id, target)
      setStaff(updated)
      setTarget(updated.assignable_roles[0] ?? '')
      setConfirmed(false)
      setNotice(`Rol actualizado a «${roleLabel(updated.role)}». Sus sesiones se cerraron y debe iniciar sesión de nuevo.`)
    } catch (error) {
      setFailure(toFailure(error, 'role'))
    } finally {
      setBusy(false)
    }
  }

  const isOwn = staff !== null && session?.user.id === staff.id

  return (
    <section aria-labelledby={`${id}-title`} className="admin-card">
      <h2 id={`${id}-title`}>Cambiar el rol de una persona del personal</h2>
      <p className="admin-intro">
        Solo se puede alternar entre agente de soporte y auditor de seguridad. Cada persona tiene un único rol, y el
        cambio cierra sus sesiones al instante.
      </p>
      <form aria-labelledby={`${id}-title`} className="admin-form" noValidate onSubmit={(event) => void load(event)}>
        <div className="admin-field">
          <label htmlFor={`${id}-id`}>ID de la cuenta del personal</label>
          <input
            aria-invalid={fieldError ? true : undefined}
            autoComplete="off"
            id={`${id}-id`}
            inputMode="numeric"
            onChange={(event) => setIdText(event.currentTarget.value)}
            value={idText}
          />
          {fieldError && <p className="admin-field-error" role="alert">{fieldError}</p>}
        </div>
        <button className="secondary-button" disabled={loading} type="submit">{loading ? 'Consultando…' : 'Consultar rol'}</button>
      </form>
      <p aria-live="polite" className="admin-notice" data-testid="admin-role-notice">{notice}</p>
      {failure && <AdminFailureNotice failure={failure} />}
      {staff && (
        <div className="admin-card admin-nested" data-testid="admin-staff-result">
          <h3>{staff.email}</h3>
          <dl className="admin-definition">
            <div><dt>ID</dt><dd>{staff.id}</dd></div>
            <div><dt>Rol actual</dt><dd>{roleLabel(staff.role)}</dd></div>
            <div><dt>Estado</dt><dd>{statusLabel(staff.status)}</dd></div>
            <div><dt>Registro</dt><dd>{formatDateTime(staff.registered_at)}</dd></div>
          </dl>
          {isOwn ? (
            <p className="admin-hint">No puedes cambiar tu propio rol.</p>
          ) : staff.assignable_roles.length === 0 ? (
            <p className="admin-hint" data-testid="admin-role-locked">El rol de administrador no se cambia desde el portal.</p>
          ) : (
            <form aria-label="Cambiar rol" className="admin-confirm" onSubmit={(event) => void change(event)}>
              <div className="admin-field">
                <label htmlFor={`${id}-new-role`}>Nuevo rol</label>
                <select id={`${id}-new-role`} onChange={(event) => setTarget(event.currentTarget.value as PortalStaffRole)} value={target}>
                  {staff.assignable_roles.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
                </select>
              </div>
              <label className="admin-check">
                <input checked={confirmed} onChange={(event) => setConfirmed(event.currentTarget.checked)} type="checkbox" />
                {' '}Entiendo que sus sesiones se cerrarán y que un auditor deberá completar la verificación en dos pasos.
              </label>
              <button className="primary-button" disabled={!confirmed || busy || target === ''} type="submit">
                {busy ? 'Aplicando…' : 'Confirmar cambio de rol'}
              </button>
            </form>
          )}
        </div>
      )}
    </section>
  )
}
