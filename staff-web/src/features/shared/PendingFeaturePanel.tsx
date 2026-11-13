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
        <div><h2>Solo estructura</h2><p>Esta sección aún no está implementada. Los datos reales y las acciones protegidas permanecerán desactivados hasta conectar la autenticación segura del personal.</p></div>
        <span className="status-pill">NO DISPONIBLE</span>
      </div>
    </section>
  )
}
