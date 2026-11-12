import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from './AppRouter'

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

function deniedResponse(): Response {
  return jsonResponse({ code: 'session_invalid', status: 401, title: 'Unauthorized' }, 401)
}

describe('staff portal authentication routes', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/')
    sessionStorage.clear()
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return deniedResponse()
      return jsonResponse({ code: 'invalid_credentials', status: 401 }, 401)
    }))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('keeps the overview public and exposes only Support Agent navigation', async () => {
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Your support workspace starts here.' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Support' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Administration' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Security audit' })).not.toBeInTheDocument()
  })

  it('redirects direct support navigation to sign-in and hides the protected page', async () => {
    window.history.pushState({}, '', '/support')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Sign in to the support portal' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Customer support' })).not.toBeInTheDocument()
  })

  it('shows a recoverable protected-route error and retries session confirmation', async () => {
    let sessionRequests = 0
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) {
        sessionRequests += 1
        return sessionRequests === 1
          ? jsonResponse({ code: 'service_unavailable', status: 503 }, 503)
          : jsonResponse(validSession)
      }
      return deniedResponse()
    })
    window.history.pushState({}, '', '/support')
    const user = userEvent.setup()
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-auth-recoverable-error')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Customer support' })).not.toBeInTheDocument()
    await user.click(screen.getByTestId('staff-auth-retry-button'))
    expect(await screen.findByRole('heading', { name: 'Customer support' })).toBeInTheDocument()
  })

  it('keeps protected content hidden while logout is pending and allows an explicit retry', async () => {
    sessionStorage.setItem('finance-ai-staff-logout-pending', '1')
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/logout')) return new Response(null, { status: 204 })
      return deniedResponse()
    })
    window.history.pushState({}, '', '/support')
    const user = userEvent.setup()
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-logout-pending')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Customer support' })).not.toBeInTheDocument()
    await user.click(screen.getByTestId('staff-logout-retry-button'))
    expect(await screen.findByRole('heading', { name: 'Sign in to the support portal' })).toBeInTheDocument()
    expect(sessionStorage.getItem('finance-ai-staff-logout-pending')).toBeNull()
  })

  it('submits credentials and opens Support only after a server-confirmed support_agent session', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
      if (String(input).endsWith('/session')) return deniedResponse()
      if (String(input).endsWith('/login')) {
        expect(init?.credentials).toBe('include')
        expect(init?.headers).toBeInstanceOf(Headers)
        return jsonResponse(validSession)
      }
      return jsonResponse({ code: 'session_invalid' }, 401)
    })
    window.history.pushState({}, '', '/login')
    const user = userEvent.setup()
    render(<AppRouter />)

    await user.type(await screen.findByLabelText('Email'), 'agent@example.test')
    await user.type(screen.getByLabelText('Password'), 'example-only-password')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('heading', { name: 'Customer support' })).toBeInTheDocument()
    expect(screen.getByText('agent@example.test')).toBeInTheDocument()
  })

  it('keeps credential submission visibly pending while the server request is unresolved', async () => {
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return deniedResponse()
      return new Promise<Response>(() => {})
    })
    window.history.pushState({}, '', '/login')
    const user = userEvent.setup()
    render(<AppRouter />)

    await user.type(await screen.findByLabelText('Email'), 'agent@example.test')
    await user.type(screen.getByLabelText('Password'), 'example-only-password')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('button', { name: 'Signing in…' })).toBeDisabled()
  })

  it('does not open the protected route when the server returns a different staff role', async () => {
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return deniedResponse()
      return jsonResponse({ ...validSession, user: { ...validSession.user, role: 'admin' } })
    })
    window.history.pushState({}, '', '/login')
    const user = userEvent.setup()
    render(<AppRouter />)

    await user.type(await screen.findByLabelText('Email'), 'admin@example.test')
    await user.type(screen.getByLabelText('Password'), 'example-only-password')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    await waitFor(() => expect(screen.getByRole('heading', { name: 'Sign in to the support portal' })).toBeInTheDocument())
    expect(screen.queryByRole('heading', { name: 'Customer support' })).not.toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent(/access is no longer available/i)
  })

  it('does not route admin or audit paths to staff features', async () => {
    window.history.pushState({}, '', '/admin')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'That page is not here' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Administration' })).not.toBeInTheDocument()
  })
})
