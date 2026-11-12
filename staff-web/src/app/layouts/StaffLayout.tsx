import { NavLink, Outlet } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

const navigation = [
  { to: '/', label: 'Overview', end: true },
  { to: '/support', label: 'Support' },
]

export function StaffLayout() {
  const { state, logout } = useStaffAuth()
  const authenticated = state.status === 'authenticated'
  const identity = authenticated ? state.session.user.email : null

  return (
    <div className="portal-shell">
      <a className="skip-link" href="#main-content">Skip to content</a>
      <aside aria-label="Staff navigation" className="sidebar">
        <NavLink aria-label="FinanciAI staff home" className="brand" to="/">
          <span aria-hidden="true" className="brand-mark">F</span>
          <span><strong>FinanciAI</strong><small>Staff workspace</small></span>
        </NavLink>
        <p className="nav-label">WORKSPACE</p>
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
          <span><strong>{authenticated ? 'Support agent' : 'Staff access protected'}</strong><small>{identity ?? 'Sign in to open Support'}</small></span>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <div><span className="eyebrow">FINANCIAI · INTERNAL</span><p>Support workspace</p></div>
          {authenticated
            ? <button className="sign-in-link sign-out-button" data-testid="staff-sign-out-button" onClick={() => void logout()} type="button">Sign out</button>
            : <NavLink className="sign-in-link" data-testid="staff-sign-in-link" to="/login">Sign in</NavLink>}
        </header>
        <main className="page-content" id="main-content"><Outlet /></main>
        <footer className="page-footer">Support access is confirmed by the staff session service.</footer>
      </div>
    </div>
  )
}
