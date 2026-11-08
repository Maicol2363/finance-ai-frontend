import { NavLink, Outlet } from 'react-router'

const navigation = [
  { to: '/', label: 'Overview', end: true },
  { to: '/support', label: 'Support' },
  { to: '/admin', label: 'Administration' },
  { to: '/audit', label: 'Security audit' },
]

export function StaffLayout() {
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
          <span aria-hidden="true" className="status-dot" />
          <span><strong>Sign-in unavailable</strong><small>Authentication is not connected</small></span>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <div><span className="eyebrow">FINANCIAI · INTERNAL</span><p>Support and security workspace</p></div>
          <NavLink className="sign-in-link" to="/login">Sign in</NavLink>
        </header>
        <main className="page-content" id="main-content"><Outlet /></main>
        <footer className="page-footer">Staff tools are unavailable until secure sign-in is connected.</footer>
      </div>
    </div>
  )
}
