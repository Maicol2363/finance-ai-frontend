type LoadingStateProps = {
  label?: string
}

export function LoadingState({ label = 'Cargando el espacio del personal…' }: LoadingStateProps) {
  return <p aria-live="polite" className="async-state" role="status">{label}</p>
}

type ErrorStateProps = {
  title?: string
  onRetry?: () => void
}

export function ErrorState({ title = 'No se pudo cargar este espacio.', onRetry }: ErrorStateProps) {
  return (
    <section aria-labelledby="load-error-title" className="async-state error-state" role="alert">
      <h2 id="load-error-title">Ocurrió un error</h2>
      <p>{title}</p>
      {onRetry && <button onClick={onRetry} type="button">Intentar de nuevo</button>}
    </section>
  )
}
