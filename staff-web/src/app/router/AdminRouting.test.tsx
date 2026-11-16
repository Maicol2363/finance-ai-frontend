import { render, screen, waitFor } from '@testing-library/react'
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

describe('administrator workspace during session revalidation', () => {
  beforeEach(() => {
    sessionStorage.clear()
  })
  afterEach(() => vi.unstubAllGlobals())

  it('hides the workspace while the session is re-confirmed, then shows it again with what was typed', async () => {
    let sessionCalls = 0
    let release: (() => void) | undefined
    const gate = new Promise<void>((resolve) => { release = resolve })
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/staff/auth/session')) {
        sessionCalls += 1
        if (sessionCalls > 1) await gate
        return jsonResponse(session('admin'))
      }
      return jsonResponse({ code: 'session_invalid' }, 401)
    }))
    window.history.pushState({}, '', '/admin/staff')
    const user = userEvent.setup()
    render(<AppRouter />)
    const email = await screen.findByLabelText('Correo electrónico')
    await user.type(email, 'nueva.persona@example.com')

    // A returning tab (or the 30 s timer) re-confirms the session; the answer is still pending.
    document.dispatchEvent(new Event('visibilitychange'))
    expect(await screen.findByTestId('staff-auth-loading')).toBeInTheDocument()
    // Hidden from people and assistive technology, and not interactive...
    expect(screen.queryByRole('textbox', { name: 'Correo electrónico' })).not.toBeInTheDocument()
    expect(email.closest('[aria-hidden="true"]')).not.toBeNull()
    expect(email.closest('[inert]')).not.toBeNull()
    // ...but not redirected away and not emptied: the workspace is only hidden.
    expect(window.location.pathname).toBe('/admin/staff')

    release?.()
    await waitFor(() => expect(screen.queryByTestId('staff-auth-loading')).not.toBeInTheDocument())
    expect(screen.getByLabelText('Correo electrónico')).toBe(email)
    expect(email).toHaveValue('nueva.persona@example.com')
    expect(window.location.pathname).toBe('/admin/staff')
  })

  it('removes the workspace for good when the re-confirmation is denied', async () => {
    let sessionCalls = 0
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      if (String(input).endsWith('/staff/auth/session')) {
        sessionCalls += 1
        return sessionCalls === 1 ? jsonResponse(session('admin')) : jsonResponse({ code: 'staff_access_denied' }, 403)
      }
      return jsonResponse({ code: 'session_invalid' }, 401)
    }))
    window.history.pushState({}, '', '/admin/staff')
    const user = userEvent.setup()
    const { container } = render(<AppRouter />)
    await user.type(await screen.findByLabelText('Correo electrónico'), 'secreto@example.com')

    document.dispatchEvent(new Event('visibilitychange'))

    await waitFor(() => expect(screen.getByTestId('staff-sign-in-page')).toBeInTheDocument())
    expect(container.querySelector('input[value="secreto@example.com"]')).toBeNull()
    expect(document.body.textContent).not.toContain('secreto@example.com')
  })
})

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

    expect(await screen.findByTestId('staff-role-forbidden')).toHaveTextContent('No tienes permisos para acceder a estas funciones')
    expect(screen.queryByRole('heading', { name: 'Administración' })).not.toBeInTheDocument()
    expect(protectedRequests('/staff/admin/')).toEqual([])
    expect(screen.getByRole('link', { name: 'Volver a mi espacio de trabajo' })).toHaveAttribute('href', '/support')
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

    expect(await screen.findByTestId('staff-role-forbidden')).toHaveTextContent('No tienes permisos para acceder a estas funciones')
    expect(screen.getByRole('link', { name: 'Volver a mi espacio de trabajo' })).toHaveAttribute('href', '/admin')
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
