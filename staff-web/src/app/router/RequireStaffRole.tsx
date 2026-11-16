import type { ReactNode } from 'react'
import { Link, Navigate } from 'react-router'
import type { StaffRole } from '../../shared/api/staffAuthApi'
import { ROLE_HOME } from '../../shared/auth/roleHome'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

/**
 * Renders a workspace only for its own role. Another role sees a standard permission notice,
 * no data, and triggers no request for it. This is presentation only: every API operation is
 * authorized by the backend.
 */
export function RequireStaffRole({ role, children }: { role: StaffRole; children: ReactNode }) {
  const { session } = useStaffAuth()
  if (!session) return <Navigate to="/login" replace />
  if (session.user.role === role) return children

  return (
    <section aria-labelledby="role-forbidden-title" className="feature-page" data-testid="staff-role-forbidden">
      <div className="page-heading">
        <span className="eyebrow">ACCESO DENEGADO</span>
        <h1 id="role-forbidden-title">No tienes permisos para acceder a estas funciones</h1>
        <p>Tu cuenta no tiene autorización para usar esta sección. Si necesitas acceso, solicítalo a un administrador.</p>
      </div>
      <Link className="text-link" to={ROLE_HOME[session.user.role]}>Volver a mi espacio de trabajo</Link>
    </section>
  )
}

export function RoleHomeRedirect() {
  const { session } = useStaffAuth()
  if (!session) return <Navigate to="/login" replace />
  return <Navigate to={ROLE_HOME[session.user.role]} replace />
}
