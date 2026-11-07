type PendingFeaturePanelProps = {
  eyebrow: string
  title: string
  description: string
}

export function PendingFeaturePanel({ eyebrow, title, description }: PendingFeaturePanelProps) {
  return (
    <section aria-labelledby="feature-title" className="feature-page">
      <div className="page-heading">
        <span className="eyebrow">{eyebrow}</span>
        <h1 id="feature-title">{title}</h1>
        <p>{description}</p>
      </div>
      <div className="pending-panel">
        <span aria-hidden="true" className="pending-icon">◷</span>
        <div><h2>Foundation only</h2><p>This area is not implemented. Live data and protected actions stay disabled until secure staff authentication is connected.</p></div>
        <span className="status-pill">NOT READY</span>
      </div>
    </section>
  )
}
