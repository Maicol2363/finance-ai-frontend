import { Outlet } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { ThemeToggleButton } from '../../shared/theme/ThemeToggleButton'

export function StaffLayout() {
  const { state, logout } = useStaffAuth()
  const authenticated = state.status === 'authenticated'
  const identity = authenticated ? state.session.user.email : null
  const footer = authenticated && state.session.user.role === 'security_auditor'
    ? 'El acceso a Auditoría se confirma en cada solicitud con el rol, la cuenta activa y la verificación en dos pasos.'
    : 'El acceso a Soporte se confirma con el servicio de sesiones del personal.'

  return (
    <div className="portal-shell">
      <a className="skip-link" href="#main-content">Saltar al contenido</a>
      <div className="workspace">
        <header className="topbar">
          <div aria-label="FinanciAI, portal del personal" className="brand">
            <img alt="" aria-hidden="true" className="brand-logo" src="/finance-ai-app-icon.png" />
            <span><strong>FinanciAI</strong><small>Portal del personal</small></span>
          </div>
          <div className="topbar-actions">
            {identity && <span className="staff-identity">{identity}</span>}
            <ThemeToggleButton />
            <button className="sign-in-link sign-out-button" data-testid="staff-sign-out-button" onClick={() => void logout()} type="button">Cerrar sesión</button>
          </div>
        </header>
        <main className="page-content" id="main-content"><Outlet /></main>
        <footer className="page-footer">{footer}</footer>
      </div>
    </div>
  )
}
