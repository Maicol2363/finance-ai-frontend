import { Navigate, NavLink, Route, Routes } from 'react-router'
import { AccountsPage } from './AccountsPage'
import { EscalationsPage } from './EscalationsPage'
import { SecurityPage } from './SecurityPage'
import { StaffPage } from './StaffPage'

const SECTIONS = [
  { to: '/admin/accounts', label: 'Cuentas' },
  { to: '/admin/staff', label: 'Personal' },
  { to: '/admin/tickets', label: 'Casos escalados' },
  { to: '/admin/security', label: 'Seguridad' },
] as const

/**
 * Administrator workspace (ADM-01..ADM-05). Links are absolute because relative links inside the
 * splat route would resolve against the current sub-page. Navigation is presentation only: every operation
 * is authorized by the backend against the current role, account state and MFA-verified session.
 */
export function AdminWorkspacePage() {
  return (
    <section aria-labelledby="admin-title" className="admin-workspace">
      <div className="page-heading">
        <p className="eyebrow">ADMINISTRADOR</p>
        <h1 id="admin-title">Administración</h1>
        <p>
          Gestiona cuentas de acceso, personal y casos escalados. Este espacio no da acceso a finanzas privadas,
          facturación ni configuración de infraestructura, y no puede crear ni retirar administradores.
        </p>
      </div>
      <nav aria-label="Secciones de administración" className="audit-tabs">
        {SECTIONS.map((section) => (
          <NavLink className={({ isActive }) => `audit-tab${isActive ? ' is-active' : ''}`} key={section.to} to={section.to}>
            {section.label}
          </NavLink>
        ))}
      </nav>
      <Routes>
        <Route element={<Navigate replace to="/admin/accounts" />} index />
        <Route element={<AccountsPage />} path="accounts" />
        <Route element={<StaffPage />} path="staff" />
        <Route element={<EscalationsPage />} path="tickets" />
        <Route element={<SecurityPage />} path="security" />
        <Route element={<Navigate replace to="/admin/accounts" />} path="*" />
      </Routes>
    </section>
  )
}
