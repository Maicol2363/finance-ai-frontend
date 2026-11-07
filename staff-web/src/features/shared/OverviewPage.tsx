import { Link } from 'react-router'

const areas = [
  { title: 'Customer support', detail: 'Ticket workflows are pending.', to: '/support', tag: 'SUPPORT AGENT' },
  { title: 'Administration', detail: 'Account and staff controls are pending.', to: '/admin', tag: 'ADMIN' },
  { title: 'Security audit', detail: 'Read-only event review is pending.', to: '/audit', tag: 'SECURITY AUDITOR' },
]

export function OverviewPage() {
  return (
    <section className="overview-page">
      <div className="welcome-card">
        <div className="welcome-copy">
          <span className="eyebrow">STAFF PORTAL FOUNDATION</span>
          <h1>Good work starts with a clear view.</h1>
          <p>The shared workspace is ready for role-by-role implementation. Business features remain disabled until secure staff authentication is available.</p>
          <Link className="primary-button" to="/login">View sign-in status <span aria-hidden="true">→</span></Link>
        </div>
        <div aria-hidden="true" className="welcome-art"><span className="orbit orbit-one" /><span className="orbit orbit-two" /><span className="art-core">F</span></div>
      </div>
      <div className="section-heading">
        <div><span className="eyebrow">ROLE WORKSPACES</span><h2>Ready for implementation</h2></div>
        <span className="status-pill">3 AREAS PLANNED</span>
      </div>
      <div className="area-grid">
        {areas.map((area) => (
          <Link className="area-card" key={area.to} to={area.to}>
            <span className="area-tag">{area.tag}</span><h3>{area.title}</h3><p>{area.detail}</p><span aria-hidden="true" className="area-arrow">↗</span>
          </Link>
        ))}
      </div>
      <p className="foundation-note"><span aria-hidden="true">ⓘ</span> This screen shows planned areas only. It does not display live data or perform staff operations.</p>
    </section>
  )
}
