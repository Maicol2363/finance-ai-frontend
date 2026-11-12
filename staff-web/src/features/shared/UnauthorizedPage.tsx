import { Link } from 'react-router'

export function UnauthorizedPage() {
  return (
    <section className="feature-page">
      <div className="page-heading"><span className="eyebrow">VERIFICACIÓN DE ACCESO</span><h1>El acceso no está disponible</h1><p>El inicio de sesión y la autorización por rol aún no están conectados en esta estructura.</p></div>
      <Link className="text-link" to="/">Volver al inicio</Link>
    </section>
  )
}
