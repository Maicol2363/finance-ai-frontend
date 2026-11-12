import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from '../../app/router/AppRouter'

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

function problem(code: string, status: number): Response {
  return jsonResponse({ code, status, title: 'Request failed' }, status)
}

describe('staff authentication integration', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/')
    sessionStorage.clear()
    vi.stubGlobal('fetch', vi.fn(async () => problem('session_invalid', 401)))
  })

  afterEach(() => vi.unstubAllGlobals())

  it('restores Support on direct navigation only after C1 confirms the session', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockResolvedValueOnce(jsonResponse(validSession))
    window.history.pushState({}, '', '/support')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Atención al cliente' })).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledOnce()
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe('/api/v1/staff/auth/session')
    expect(await screen.findByText('agent@example.test')).toBeInTheDocument()
  })

  it('renews an expired access session through the refresh endpoint', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return problem('access_expired', 401)
      if (String(input).endsWith('/refresh')) return jsonResponse(validSession)
      return problem('session_invalid', 401)
    })
    window.history.pushState({}, '', '/support')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Atención al cliente' })).toBeInTheDocument()
    const refreshCall = fetchMock.mock.calls.find(([input]) => String(input).endsWith('/refresh'))
    expect(refreshCall).toBeDefined()
    expect(refreshCall?.[1]?.method).toBe('POST')
    expect(refreshCall?.[1]?.credentials).toBe('include')
    expect(JSON.parse(String(refreshCall?.[1]?.body))).toEqual({})
    expect(new Headers(refreshCall?.[1]?.headers).get('X-Staff-Request')).toBe('1')
  })

  it('shows a safe restore diagnostic with a sanitized API location and correlation id', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(
      JSON.stringify({ code: 'service_unavailable', detail: 'raw-body-password-token' }),
      {
        status: 503,
        headers: {
          'Content-Type': 'application/problem+json',
          'X-Correlation-ID': 'restore-request-7',
        },
      },
    )))
    window.history.pushState({}, '', '/support')
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-auth-recoverable-error')).toBeInTheDocument()
    const report = screen.getByLabelText('Contenido del informe de diagnóstico').textContent ?? ''
    expect(report).toContain('Código del error: service_unavailable')
    expect(report).toContain('Operación: staff.auth.session')
    expect(report).toContain('Ubicación de la API: /api/v1/staff/auth/session')
    expect(report).toContain('Id. de solicitud/correlación: restore-request-7')
    expect(report).not.toMatch(/raw-body-password-token|agent@example\.test|Bearer|access_token/)
  })

  it('shows and copies a privacy-safe login failure report', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return problem('session_invalid', 401)
      if (String(input).endsWith('/login')) {
        return new Response(JSON.stringify({
          code: 'invalid_credentials',
          detail: 'raw-body-password-token',
        }), {
          status: 401,
          headers: {
            'Content-Type': 'application/problem+json',
            'X-Correlation-ID': 'support@example.test',
          },
        })
      }
      return problem('unknown_error', 404)
    })
    const user = userEvent.setup()
    const writeText = vi.fn<Clipboard['writeText']>().mockResolvedValue()
    const previousClipboard = Object.getOwnPropertyDescriptor(navigator, 'clipboard')
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })
    window.history.pushState({}, '', '/login')
    render(<AppRouter />)

    try {
      await user.type(await screen.findByRole('textbox', { name: 'Correo electrónico' }), 'support@example.test')
      await user.type(screen.getByLabelText('Contraseña'), 'not-persisted-password')
      await user.click(screen.getByRole('button', { name: 'Iniciar sesión' }))

      const reportElement = await screen.findByLabelText('Contenido del informe de diagnóstico')
      const report = reportElement.textContent ?? ''
      expect(report).toContain('Código del error: invalid_credentials')
      expect(report).toContain('Operación: staff.auth.login')
      expect(report).toContain('Ubicación de la API: /api/v1/staff/auth/login')
      expect(report).toContain('Id. de solicitud/correlación: no_disponible')
      expect(report).not.toMatch(/support@example\.test|not-persisted-password|raw-body-password-token|Bearer|access_token/)

      await user.click(screen.getByTestId('staff-auth-diagnostic-copy-button'))
      expect(writeText).toHaveBeenCalledExactlyOnceWith(report)
      expect(await screen.findByRole('status')).toHaveTextContent('Se copió el informe de diagnóstico.')
    } finally {
      if (previousClipboard) Object.defineProperty(navigator, 'clipboard', previousClipboard)
      else Reflect.deleteProperty(navigator, 'clipboard')
    }
  })

  it('keeps a session with an unexpected role outside Support', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse({
      ...validSession,
      user: { ...validSession.user, role: 'security_auditor' },
    }))
    window.history.pushState({}, '', '/support')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Iniciar sesión en el portal de soporte' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Atención al cliente' })).not.toBeInTheDocument()
  })

  it('clears the pending marker and confirms sign-out only after HTTP 204', async () => {
    const fetchMock = vi.mocked(fetch)
    fetchMock.mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return jsonResponse(validSession)
      if (String(input).endsWith('/logout')) return new Response(null, { status: 204 })
      return problem('session_invalid', 401)
    })
    window.history.pushState({}, '', '/support')
    const user = userEvent.setup()
    render(<AppRouter />)

    await user.click(await screen.findByTestId('staff-sign-out-button'))
    expect(await screen.findByRole('heading', { name: 'Iniciar sesión en el portal de soporte' })).toBeInTheDocument()
    expect(screen.queryByTestId('staff-logout-pending')).not.toBeInTheDocument()
    expect(sessionStorage.getItem('finance-ai-staff-logout-pending')).toBeNull()
    expect(fetchMock.mock.calls.some(([input]) => String(input).endsWith('/logout'))).toBe(true)
  })

  it('keeps the protected view hidden and stores only a marker after ambiguous logout', async () => {
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) return jsonResponse(validSession)
      if (String(input).endsWith('/logout')) throw new TypeError('simulated disconnect')
      return problem('session_invalid', 401)
    })
    window.history.pushState({}, '', '/support')
    const user = userEvent.setup()
    render(<AppRouter />)

    await user.click(await screen.findByTestId('staff-sign-out-button'))
    expect(await screen.findByTestId('staff-logout-pending')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Atención al cliente' })).not.toBeInTheDocument()
    expect(screen.queryByText(/signed out/i)).not.toBeInTheDocument()
    expect(Object.entries(sessionStorage)).toEqual([['finance-ai-staff-logout-pending', '1']])
    const report = screen.getByLabelText('Contenido del informe de diagnóstico').textContent ?? ''
    expect(report).toContain('Código del error: network_error')
    expect(report).toContain('Operación: staff.auth.logout')
    expect(report).not.toMatch(/simulated disconnect|agent@example\.test|access_token|refresh_token/)
  })

  it('lets a user explicitly retry a recoverable session check', async () => {
    let sessionCalls = 0
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/session')) {
        sessionCalls += 1
        return sessionCalls === 1 ? problem('service_unavailable', 503) : jsonResponse(validSession)
      }
      return problem('session_invalid', 401)
    })
    window.history.pushState({}, '', '/support')
    const user = userEvent.setup()
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-auth-recoverable-error')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Atención al cliente' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Intentar de nuevo' }))
    await waitFor(() => expect(screen.getByRole('heading', { name: 'Atención al cliente' })).toBeInTheDocument())
    expect(sessionCalls).toBe(2)
  })
})
