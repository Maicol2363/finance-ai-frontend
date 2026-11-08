import { Link } from 'react-router'

export function UnauthorizedPage() {
  return (
    <section className="feature-page">
      <div className="page-heading"><span className="eyebrow">ACCESS CHECK</span><h1>Access is not available</h1><p>Sign-in and role authorization are not connected in this foundation.</p></div>
      <Link className="text-link" to="/">Return to overview</Link>
    </section>
  )
}
