import { Link } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

export function OverviewPage() {
  const { state } = useStaffAuth()
  const authenticated = state.status === 'authenticated'

  return (
    <section className="overview-page">
      <div className="welcome-card">
        <div className="welcome-copy">
          <span className="eyebrow">ESPACIO DE AGENTES DE SOPORTE</span>
          <h1>Tu espacio de soporte empieza aquí.</h1>
          <p>El servidor verifica el acceso del personal. Inicia sesión para abrir el espacio de soporte.</p>
          <Link className="primary-button" to={authenticated ? '/support' : '/login'}>{authenticated ? 'Abrir Soporte' : 'Iniciar sesión'} <span aria-hidden="true">→</span></Link>
        </div>
        <div aria-hidden="true" className="welcome-art"><span className="orbit orbit-one" /><span className="orbit orbit-two" /><span className="art-core">F</span></div>
      </div>
      <div className="section-heading">
        <div><span className="eyebrow">ACCESO DEL PERSONAL</span><h2>{authenticated ? 'El acceso a Soporte está activo' : 'Se requiere iniciar sesión'}</h2></div>
        <span className="status-pill">AGENTE DE SOPORTE</span>
      </div>
      <div className="area-grid">
        <Link className="area-card" to={authenticated ? '/support' : '/login'}>
          <span className="area-tag">AGENTE DE SOPORTE</span><h3>Atención al cliente</h3><p>{authenticated ? 'Abre el espacio protegido de soporte.' : 'Inicia sesión con una cuenta de agente de soporte autorizada para continuar.'}</p><span aria-hidden="true" className="area-arrow">↗</span>
        </Link>
      </div>
      <p className="foundation-note"><span aria-hidden="true">ⓘ</span> Solo los agentes de soporte confirmados por el servidor pueden acceder a las secciones del personal.</p>
    </section>
  )
}
