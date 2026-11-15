import type { ReactNode } from 'react'
import { Link, Navigate } from 'react-router'
import type { StaffRole } from '../../shared/api/staffAuthApi'
import { ROLE_HOME } from '../../shared/auth/roleHome'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

const ROLE_LABELS: Readonly<Record<StaffRole, string>> = {
  support_agent: 'Agente de soporte',
  security_auditor: 'Auditor de seguridad',
  admin: 'Administrador',
}

/**
 * Renders a workspace only for its own role. Another role sees no data and triggers no
 * request for it. This is presentation only: every API operation is authorized by the backend.
 */
export function RequireStaffRole({ role, children }: { role: StaffRole; children: ReactNode }) {
  const { session } = useStaffAuth()
  if (!session) return <Navigate to="/login" replace />
  if (session.user.role === role) return children

  const ownRole = session.user.role
  return (
    <section aria-labelledby="role-forbidden-title" className="feature-page" data-testid="staff-role-forbidden">
      <div className="page-heading">
        <span className="eyebrow">ACCESO DENEGADO</span>
        <h1 id="role-forbidden-title">Esta sección no corresponde a tu rol</h1>
        <p>
          Tu cuenta tiene el rol «{ROLE_LABELS[ownRole]}» y solo puede usar su propio espacio. Esta sección
          pertenece al rol «{ROLE_LABELS[role]}».
        </p>
      </div>
      <Link className="text-link" to={ROLE_HOME[ownRole]}>Ir a mi espacio</Link>
    </section>
  )
}

export function RoleHomeRedirect() {
  const { session } = useStaffAuth()
  if (!session) return <Navigate to="/login" replace />
  return <Navigate to={ROLE_HOME[session.user.role]} replace />
}
