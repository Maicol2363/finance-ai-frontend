import { NavLink, Outlet } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { ThemeToggleButton } from '../../shared/theme/ThemeToggleButton'

const navigation = [
  { to: '/', label: 'Inicio', end: true },
  { to: '/support', label: 'Soporte' },
]

export function StaffLayout() {
  const { state, logout } = useStaffAuth()
  const authenticated = state.status === 'authenticated'
  const identity = authenticated ? state.session.user.email : null

  return (
    <div className="portal-shell">
      <a className="skip-link" href="#main-content">Saltar al contenido</a>
      <aside aria-label="Navegación del personal" className="sidebar">
        <NavLink aria-label="Inicio de FinanciAI" className="brand" to="/">
          <span aria-hidden="true" className="brand-mark">F</span>
          <span><strong>FinanciAI</strong><small>Portal del personal</small></span>
        </NavLink>
        <p className="nav-label">ESPACIO DE TRABAJO</p>
        <nav className="primary-nav">
          {navigation.map(({ to, label, end }) => (
            <NavLink
              className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}
              end={end}
              key={to}
              to={to}
            >
              <span aria-hidden="true" className="nav-indicator" />{label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <span aria-hidden="true" className={`status-dot${authenticated ? ' status-dot-active' : ''}`} />
          <span><strong>{authenticated ? 'Agente de soporte' : 'Acceso protegido'}</strong><small>{identity ?? 'Inicia sesión para abrir Soporte'}</small></span>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <div><span className="eyebrow">FINANCIAI · INTERNO</span><p>Espacio de soporte</p></div>
          <div className="topbar-actions">
            <ThemeToggleButton />
            {authenticated
              ? <button className="sign-in-link sign-out-button" data-testid="staff-sign-out-button" onClick={() => void logout()} type="button">Cerrar sesión</button>
              : <NavLink className="sign-in-link" data-testid="staff-sign-in-link" to="/login">Iniciar sesión</NavLink>}
          </div>
        </header>
        <main className="page-content" id="main-content"><Outlet /></main>
        <footer className="page-footer">El acceso a Soporte se confirma con el servicio de sesiones del personal.</footer>
      </div>
    </div>
  )
}
