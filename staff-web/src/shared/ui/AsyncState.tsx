type LoadingStateProps = {
  label?: string
}

export function LoadingState({ label = 'Loading staff workspace…' }: LoadingStateProps) {
  return <p aria-live="polite" className="async-state" role="status">{label}</p>
}

type ErrorStateProps = {
  title?: string
  onRetry?: () => void
}

export function ErrorState({ title = 'We could not load this workspace.', onRetry }: ErrorStateProps) {
  return (
    <section aria-labelledby="load-error-title" className="async-state error-state" role="alert">
      <h2 id="load-error-title">Something went wrong</h2>
      <p>{title}</p>
      {onRetry && <button onClick={onRetry} type="button">Try again</button>}
    </section>
  )
}
