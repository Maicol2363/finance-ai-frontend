import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from './AppRouter'

function session(role: string) {
  return {
    user: { id: 1, email: `${role}@example.test`, role },
    access_expires_at: '2026-11-15T12:10:00Z',
    renewable_expires_at: '2026-11-15T12:15:00Z',
    absolute_expires_at: '2026-11-15T16:00:00Z',
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

function signedInAs(role: string | null) {
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input)
    if (url.endsWith('/staff/auth/session')) {
      return role ? jsonResponse(session(role)) : jsonResponse({ code: 'session_invalid' }, 401)
    }
    if (url.includes('/staff/admin/tickets/escalated')) return jsonResponse([])
    return jsonResponse({ code: 'session_invalid' }, 401)
  }))
}

function protectedRequests(prefix: string): string[] {
  return vi.mocked(fetch).mock.calls.map(([input]) => String(input)).filter((url) => url.includes(prefix))
}

describe('administrator routing', () => {
  beforeEach(() => {
    sessionStorage.clear()
  })
  afterEach(() => vi.unstubAllGlobals())

  it('sends an administrator home to the administration workspace with its sections', async () => {
    signedInAs('admin')
    window.history.pushState({}, '', '/')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Administración' })).toBeInTheDocument()
    expect(window.location.pathname).toBe('/admin/accounts')
    const nav = screen.getByRole('navigation', { name: 'Secciones de administración' })
    expect(nav).toHaveTextContent('Cuentas')
    expect(nav).toHaveTextContent('Personal')
    expect(nav).toHaveTextContent('Casos escalados')
    expect(nav).toHaveTextContent('Seguridad')
    expect(screen.getByText(/no puede crear ni retirar administradores/)).toBeInTheDocument()
    expect(screen.getByText(/Administración se confirma en cada solicitud/)).toBeInTheDocument()
  })

  it('navigates between administration sections without extra privileges', async () => {
    signedInAs('admin')
    window.history.pushState({}, '', '/admin/accounts')
    const user = userEvent.setup()
    render(<AppRouter />)

    await user.click(await screen.findByRole('link', { name: 'Personal' }))
    expect(await screen.findByRole('heading', { name: 'Invitar a una persona del personal' })).toBeInTheDocument()
    await user.click(screen.getByRole('link', { name: 'Casos escalados' }))
    expect(await screen.findByText('No hay casos escalados en esta vista')).toBeInTheDocument()
    await user.click(screen.getByRole('link', { name: 'Seguridad' }))
    expect(await screen.findByRole('heading', { name: 'Códigos de recuperación' })).toBeInTheDocument()
  })

  it('shows a no-data denial to a support agent and sends no administrator request', async () => {
    signedInAs('support_agent')
    window.history.pushState({}, '', '/admin/tickets')
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-role-forbidden')).toHaveTextContent('Esta sección no corresponde a tu rol')
    expect(screen.queryByRole('heading', { name: 'Administración' })).not.toBeInTheDocument()
    expect(protectedRequests('/staff/admin/')).toEqual([])
    expect(screen.getByRole('link', { name: 'Ir a mi espacio' })).toHaveAttribute('href', '/support')
  })

  it('keeps an auditor out of the administration workspace', async () => {
    signedInAs('security_auditor')
    window.history.pushState({}, '', '/admin')
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-role-forbidden')).toBeInTheDocument()
    expect(protectedRequests('/staff/admin/')).toEqual([])
  })

  it('keeps an administrator out of the support and audit workspaces', async () => {
    signedInAs('admin')
    window.history.pushState({}, '', '/support')
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-role-forbidden')).toHaveTextContent('Administrador')
    expect(screen.getByRole('link', { name: 'Ir a mi espacio' })).toHaveAttribute('href', '/admin')
    expect(protectedRequests('/staff/support/')).toEqual([])
    expect(protectedRequests('/staff/audit/')).toEqual([])
  })

  it('redirects anonymous visitors to sign-in instead of showing administration', async () => {
    signedInAs(null)
    window.history.pushState({}, '', '/admin/accounts')
    render(<AppRouter />)

    expect(await screen.findByRole('heading', { name: 'Iniciar sesión en el portal del personal' })).toBeInTheDocument()
    expect(protectedRequests('/staff/admin/')).toEqual([])
  })

  it('serves the activation and recovery pages without a session', async () => {
    signedInAs(null)
    window.history.pushState({}, '', '/activate')
    const { unmount } = render(<AppRouter />)
    expect(await screen.findByTestId('staff-activate-page')).toBeInTheDocument()
    unmount()

    window.history.pushState({}, '', '/recover')
    render(<AppRouter />)
    expect(await screen.findByTestId('staff-recover-page')).toBeInTheDocument()
  })

  it('links the recovery page from the sign-in page', async () => {
    signedInAs(null)
    window.history.pushState({}, '', '/login')
    render(<AppRouter />)

    expect(await screen.findByTestId('staff-recover-link')).toHaveAttribute('href', '/recover')
  })
})
