import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { StaffAuthProvider } from './StaffAuthProvider'
import { useStaffAuth } from './useStaffAuth'

const validSession = {
  user: { id: 42, email: 'agent@example.test', role: 'support_agent' },
  access_expires_at: '2026-11-11T15:30:00Z',
  renewable_expires_at: '2026-11-12T15:00:00Z',
  absolute_expires_at: '2026-11-18T15:00:00Z',
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function deniedResponse(code = 'session_invalid', status = 401): Response {
  return jsonResponse({ code, status, title: 'Unauthorized' }, status)
}

function AuthProbe() {
  const { state, session, login, logout, retry } = useStaffAuth()

  return (
    <section>
      <p data-testid="auth-status">{state.status}</p>
      <p data-testid="auth-session">{session?.user.email ?? 'none'}</p>
      <button onClick={() => void login('agent@example.test', 'example-only-password')} type="button">Login</button>
      <button onClick={() => void logout()} type="button">Logout</button>
      <button onClick={() => void retry()} type="button">Retry</button>
    </section>
  )
}

function renderProvider() {
  return render(<StaffAuthProvider><AuthProbe /></StaffAuthProvider>)
}

describe('StaffAuthProvider', () => {
  beforeEach(() => {
    sessionStorage.clear()
    vi.stubGlobal('fetch', vi.fn(async () => deniedResponse()))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('keeps the session view empty while startup restoration is unresolved', async () => {
    let finishRequest: ((response: Response) => void) | undefined
    vi.mocked(fetch).mockImplementation(() => new Promise<Response>((resolve) => { finishRequest = resolve }))

    renderProvider()

    expect(screen.getByTestId('auth-status')).toHaveTextContent('restoring')
    expect(screen.getByTestId('auth-session')).toHaveTextContent('none')
    finishRequest?.(jsonResponse(validSession))
    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('authenticated'))
  })

  it('restores a support session through the cookie-only C1 session request', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockResolvedValueOnce(jsonResponse(validSession))

    renderProvider()

    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('authenticated'))
    expect(screen.getByTestId('auth-session')).toHaveTextContent('agent@example.test')
    const [url, init] = fetchMock.mock.calls[0]!
    expect(String(url)).toBe('/api/v1/staff/auth/session')
    expect(init?.credentials).toBe('include')
    expect(new Headers(init?.headers).get('X-Staff-Request')).toBe('1')
    expect(new Headers(init?.headers).has('Authorization')).toBe(false)
  })

  it('fails closed when restoration returns a privileged role', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse({
      ...validSession,
      user: { ...validSession.user, role: 'admin' },
    }))

    renderProvider()

    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('anonymous'))
    expect(screen.getByTestId('auth-session')).toHaveTextContent('none')
  })

  it('publishes authenticated state only after the login response confirms support_agent', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockResolvedValueOnce(deniedResponse())
    fetchMock.mockResolvedValueOnce(jsonResponse(validSession))
    renderProvider()

    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('anonymous'))
    fireEvent.click(screen.getByRole('button', { name: 'Login' }))
    expect(screen.getByTestId('auth-status')).toHaveTextContent('authenticating')
    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('authenticated'))
    expect(screen.getByTestId('auth-session')).toHaveTextContent('agent@example.test')
  })

  it('removes the session view immediately and waits for a confirmed logout response', async () => {
    let finishLogout: ((response: Response) => void) | undefined
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockResolvedValueOnce(jsonResponse(validSession))
    fetchMock.mockImplementationOnce(() => new Promise<Response>((resolve) => { finishLogout = resolve }))
    renderProvider()

    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('authenticated'))
    fireEvent.click(screen.getByRole('button', { name: 'Logout' }))
    expect(screen.getByTestId('auth-status')).toHaveTextContent('logout_pending')
    expect(screen.getByTestId('auth-session')).toHaveTextContent('none')

    finishLogout?.(new Response(null, { status: 204 }))
    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('anonymous'))
    expect(sessionStorage.getItem('finance-ai-staff-logout-pending')).toBeNull()
  })

  it('retains a recoverable startup failure and retries against the server', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockResolvedValueOnce(deniedResponse('service_unavailable', 503))
    fetchMock.mockResolvedValueOnce(jsonResponse(validSession))
    renderProvider()

    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('recoverable_error'))
    expect(screen.getByTestId('auth-session')).toHaveTextContent('none')
    fireEvent.click(screen.getByRole('button', { name: 'Retry' }))
    await waitFor(() => expect(screen.getByTestId('auth-status')).toHaveTextContent('authenticated'))
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })
})
