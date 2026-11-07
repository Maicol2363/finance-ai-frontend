import { Link } from 'react-router'

export function NotFoundPage() {
  return (
    <section className="feature-page">
      <div className="page-heading"><span className="eyebrow">404 · PAGE NOT FOUND</span><h1>That page is not here</h1><p>Use the workspace navigation to open a planned area.</p></div>
      <Link className="text-link" to="/">Return to overview</Link>
    </section>
  )
}
