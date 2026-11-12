import { Link } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

export function OverviewPage() {
  const { state } = useStaffAuth()
  const authenticated = state.status === 'authenticated'

  return (
    <section className="overview-page">
      <div className="welcome-card">
        <div className="welcome-copy">
          <span className="eyebrow">SUPPORT AGENT WORKSPACE</span>
          <h1>Your support workspace starts here.</h1>
          <p>Staff access is verified by the server. Sign in to open the support workspace.</p>
          <Link className="primary-button" to={authenticated ? '/support' : '/login'}>{authenticated ? 'Open Support' : 'Sign in'} <span aria-hidden="true">→</span></Link>
        </div>
        <div aria-hidden="true" className="welcome-art"><span className="orbit orbit-one" /><span className="orbit orbit-two" /><span className="art-core">F</span></div>
      </div>
      <div className="section-heading">
        <div><span className="eyebrow">STAFF ACCESS</span><h2>{authenticated ? 'Support access is active' : 'Sign-in required'}</h2></div>
        <span className="status-pill">SUPPORT AGENT</span>
      </div>
      <div className="area-grid">
        <Link className="area-card" to={authenticated ? '/support' : '/login'}>
          <span className="area-tag">SUPPORT AGENT</span><h3>Customer support</h3><p>{authenticated ? 'Open the protected support workspace.' : 'Sign in with an authorized support agent account to continue.'}</p><span aria-hidden="true" className="area-arrow">↗</span>
        </Link>
      </div>
      <p className="foundation-note"><span aria-hidden="true">ⓘ</span> Only server-confirmed support agents can access staff routes.</p>
    </section>
  )
}
