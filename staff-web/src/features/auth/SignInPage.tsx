import { useEffect, useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'

function supportDestination(value: unknown): string {
  if (typeof value === 'string' && (value === '/support' || value.startsWith('/support/'))) return value
  return '/support'
}

export function SignInPage() {
  const { state, login, retry, retryPendingLogout } = useStaffAuth()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [secondsRemaining, setSecondsRemaining] = useState(0)
  const destination = supportDestination((location.state as { from?: unknown } | null)?.from)

  const retryAfterSeconds = state.status === 'recoverable_error' ? state.retryAfterSeconds : undefined
  useEffect(() => {
    if (!retryAfterSeconds) {
      setSecondsRemaining(0)
      return
    }
    setSecondsRemaining(retryAfterSeconds)
    const timerId = window.setInterval(() => {
      setSecondsRemaining((remaining) => Math.max(0, remaining - 1))
    }, 1000)
    return () => window.clearInterval(timerId)
  }, [retryAfterSeconds])

  async function submitCredentials(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (secondsRemaining > 0 || state.status === 'authenticating') return
    await login(email, password)
    setPassword('')
  }

  if (state.status === 'authenticated') return <Navigate to={destination} replace />
  if (state.status === 'logout_pending') {
    return (
      <section aria-live="polite" className="auth-page" data-testid="staff-logout-pending">
        <div className="auth-card error-state">
          <span className="eyebrow">SIGN-OUT PENDING</span>
          <h1>Sign-out needs confirmation</h1>
          <p>{state.message}</p>
          <button data-testid="staff-logout-retry-button" onClick={() => void retryPendingLogout()} type="button">Retry sign out</button>
          <Link className="text-link" data-testid="staff-overview-link" to="/">Return to overview</Link>
        </div>
      </section>
    )
  }
  if (state.status === 'restoring' || state.status === 'refreshing') {
    return <div aria-live="polite" className="async-state" data-testid="staff-auth-loading" role="status">Checking your staff session…</div>
  }

  const errorMessage = state.status === 'anonymous' || state.status === 'recoverable_error'
    ? state.message
    : undefined

  return (
    <section className="auth-page" data-testid="staff-sign-in-page">
      <div className="auth-card">
        <span className="eyebrow">SUPPORT AGENT ACCESS</span>
        <h1 id="staff-sign-in-heading">Sign in to the support portal</h1>
        <p className="auth-intro">Use your staff account to continue to the Support workspace.</p>
        {errorMessage && (
          <p aria-live="polite" className="auth-message" data-testid="staff-auth-message" role="alert">
            {errorMessage}
          </p>
        )}
        {state.status === 'recoverable_error' && (
          <button className="text-button" data-testid="staff-auth-retry-button" onClick={() => void retry()} type="button">Check session again</button>
        )}
        <form aria-labelledby="staff-sign-in-heading" data-testid="staff-sign-in-form" onSubmit={(event) => void submitCredentials(event)}>
          <div className="auth-field">
            <label htmlFor="staff-email">Email</label>
            <input
              autoComplete="username"
              data-testid="staff-sign-in-email-input"
              id="staff-email"
              name="email"
              onChange={(event) => setEmail(event.currentTarget.value)}
              required
              type="email"
              value={email}
            />
          </div>
          <div className="auth-field">
            <label htmlFor="staff-password">Password</label>
            <input
              autoComplete="current-password"
              data-testid="staff-sign-in-password-input"
              id="staff-password"
              name="password"
              onChange={(event) => setPassword(event.currentTarget.value)}
              required
              type="password"
              value={password}
            />
          </div>
          <button
            className="primary-button auth-submit"
            data-testid="staff-sign-in-submit-button"
            disabled={state.status === 'authenticating' || secondsRemaining > 0}
            type="submit"
          >
            {state.status === 'authenticating'
              ? 'Signing in…'
              : secondsRemaining > 0
                ? `Try again in ${secondsRemaining}s`
                : 'Sign in'}
          </button>
        </form>
        <Link className="auth-back-link" data-testid="staff-overview-link" to="/">Back to overview</Link>
      </div>
    </section>
  )
}
