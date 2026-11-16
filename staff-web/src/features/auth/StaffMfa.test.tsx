import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AppRouter } from '../../app/router/AppRouter'
import {
  parseStaffMfaEnrollment,
  parseStaffSessionView,
  StaffAuthApiError,
  staffAuthApi,
} from '../../shared/api/staffAuthApi'
import { StaffSessionCoordinator } from '../../shared/auth/staffSessionCoordinator'
import { auditorSession, jsonResponse, problem, routeFetch } from '../../test/auditFixtures'

const challenge = {
  status: 'mfa_required',
  enrollment_required: true,
  challenge_expires_at: '2026-11-14T20:05:00Z',
}
const enrollment = {
  issuer: 'FinanciAI',
  account_name: 'auditor@example.test',
  secret: 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
  otpauth_uri: 'otpauth://totp/FinanciAI:auditor%40example.test?secret=JBSWY3DPEHPK3PXP',
  qr_svg_data_url: 'data:image/svg+xml;base64,PHN2Zy8+',
}

async function signIn(user: ReturnType<typeof userEvent.setup>): Promise<void> {
  await user.type(await screen.findByLabelText('Correo electrónico'), 'auditor@example.test')
  await user.type(screen.getByLabelText('Contraseña'), 'example-only-password')
  await user.click(screen.getByRole('button', { name: 'Iniciar sesión' }))
}

describe('Security Auditor two-step sign-in', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/login')
    sessionStorage.clear()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('enrolls an authenticator, verifies a code and opens only the audit workspace', async () => {
    const fetchMock = routeFetch((url, init) => {
      if (url.pathname.endsWith('/staff/auth/session')) return problem('session_invalid', 401)
      if (url.pathname.endsWith('/staff/auth/refresh')) return problem('session_invalid', 401)
      if (url.pathname.endsWith('/staff/auth/login')) return jsonResponse(challenge, 202)
      if (url.pathname.endsWith('/staff/auth/mfa/enrollment')) return jsonResponse(enrollment)
      if (url.pathname.endsWith('/staff/auth/mfa/verify')) {
        const body = JSON.parse(String(init?.body)) as { code: string }
        return body.code === '123456' ? jsonResponse(auditorSession) : problem('mfa_code_invalid', 401)
      }
      if (url.pathname === '/api/v1/staff/audit/events') {
        return jsonResponse({ items: [], next_cursor: null, read_boundary: '2026-11-14T20:00:00Z', period: {
          start_date: '2026-11-08', end_date: '2026-11-14', time_zone: 'America/Bogota', time_zone_label: 'x',
          start_utc: '2026-11-08T05:00:00Z', end_utc: '2026-11-15T05:00:00Z',
        }, filters: {} })
      }
      return undefined
    })
    const user = userEvent.setup()
    render(<AppRouter />)

    await signIn(user)
    expect(await screen.findByRole('heading', { name: 'Configura tu autenticador' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Auditoría de seguridad' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Generar código QR' }))
    expect(await screen.findByRole('img', { name: 'Código QR para configurar la aplicación de autenticación' })).toHaveAttribute(
      'src',
      enrollment.qr_svg_data_url,
    )
    expect(screen.getByLabelText('Clave de configuración')).toHaveTextContent('JBSW Y3DP')

    const codeInput = screen.getByLabelText('Código de verificación de 6 dígitos')
    expect(codeInput).toHaveAttribute('autocomplete', 'one-time-code')
    const submit = screen.getByRole('button', { name: 'Verificar y entrar' })
    expect(submit).toBeDisabled()
    await user.type(codeInput, '12a34')
    expect(codeInput).toHaveValue('1234')
    await user.clear(codeInput)
    await user.type(codeInput, '000000')
    await user.click(submit)
    expect(await screen.findByTestId('staff-mfa-message')).toHaveTextContent(/no es válido o ya se usó/)
    expect(codeInput).toHaveValue('')
    const supportDetails = screen.getByTestId('staff-auth-diagnostic')
    expect(supportDetails).not.toHaveAttribute('open')
    await user.click(screen.getByText('Detalles para soporte'))
    expect(supportDetails).toHaveAttribute('open')
    const report = screen.getByLabelText('Contenido del informe de diagnóstico')
    expect(report).toHaveTextContent('Operación: staff.auth.mfa_verify')
    expect(report).not.toHaveTextContent(/000000|example-only-password|JBSWY3DP/)

    await user.type(codeInput, '123456')
    await user.click(screen.getByRole('button', { name: 'Verificar y entrar' }))
    expect(await screen.findByRole('heading', { name: 'Auditoría de seguridad' })).toBeInTheDocument()
    await waitFor(() => expect(window.location.pathname).toBe('/audit/events'))
    const paths = fetchMock.mock.calls.map(([input]) => String(input))
    expect(paths.some((path) => path.includes('/staff/support/'))).toBe(false)
    expect(sessionStorage.length).toBe(0)
  })

  it('returns to sign-in when the challenge expires', async () => {
    routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return problem('session_invalid', 401)
      if (url.pathname.endsWith('/staff/auth/refresh')) return problem('session_invalid', 401)
      if (url.pathname.endsWith('/staff/auth/login')) return jsonResponse({ ...challenge, enrollment_required: false }, 202)
      if (url.pathname.endsWith('/staff/auth/mfa/verify')) return problem('mfa_challenge_invalid', 401)
      return undefined
    })
    const user = userEvent.setup()
    render(<AppRouter />)
    await signIn(user)
    expect(await screen.findByRole('heading', { name: 'Ingresa tu código de verificación' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('Código de verificación de 6 dígitos'), '123456')
    await user.click(screen.getByRole('button', { name: 'Verificar y entrar' }))
    expect(await screen.findByRole('heading', { name: 'Iniciar sesión en el portal del personal' })).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent(/La verificación expiró/)
  })

  it('cancels the challenge on request', async () => {
    const fetchMock = routeFetch((url) => {
      if (url.pathname.endsWith('/staff/auth/session')) return problem('session_invalid', 401)
      if (url.pathname.endsWith('/staff/auth/refresh')) return problem('session_invalid', 401)
      if (url.pathname.endsWith('/staff/auth/login')) return jsonResponse(challenge, 202)
      if (url.pathname.endsWith('/staff/auth/mfa/cancel')) return new Response(null, { status: 204 })
      return undefined
    })
    const user = userEvent.setup()
    render(<AppRouter />)
    await signIn(user)
    await user.click(await screen.findByRole('button', { name: 'Cancelar y volver al inicio de sesión' }))
    expect(await screen.findByRole('heading', { name: 'Iniciar sesión en el portal del personal' })).toBeInTheDocument()
    await waitFor(() => expect(fetchMock.mock.calls.some(([input]) => String(input).endsWith('/mfa/cancel'))).toBe(true))
  })

  it('keeps the challenge step when the tab becomes visible again', async () => {
    const api = {
      login: vi.fn().mockResolvedValue(challenge),
      session: vi.fn().mockRejectedValue(new StaffAuthApiError(401, 'session_invalid')),
      refresh: vi.fn().mockRejectedValue(new StaffAuthApiError(401, 'session_invalid')),
      logout: vi.fn(),
    }
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null, storage: null })
    coordinator.start()
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('anonymous'))
    await coordinator.login('auditor@example.test', 'pw')
    expect(coordinator.currentState.status).toBe('mfa_required')
    const sessionCalls = api.session.mock.calls.length
    act(() => {
      document.dispatchEvent(new Event('visibilitychange'))
    })
    expect(coordinator.currentState.status).toBe('mfa_required')
    expect(api.session.mock.calls.length).toBe(sessionCalls)
    coordinator.stop()
  })

  it('surfaces rate limiting and unavailable verification as recoverable MFA messages', async () => {
    const api = {
      login: vi.fn().mockResolvedValue({ ...challenge, enrollment_required: false }),
      session: vi.fn(),
      refresh: vi.fn(),
      logout: vi.fn(),
      verifyMfa: vi.fn()
        .mockRejectedValueOnce(new StaffAuthApiError(429, 'mfa_rate_limited', null, 60, 'mfa_verify'))
        .mockRejectedValueOnce(new StaffAuthApiError(503, 'mfa_unavailable', 'abc', null, 'mfa_verify')),
      startMfaEnrollment: vi.fn().mockRejectedValue(new StaffAuthApiError(409, 'mfa_already_enrolled')),
    }
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null, storage: null })
    await coordinator.login('auditor@example.test', 'pw')
    await coordinator.verifyMfa('123456')
    let state = coordinator.currentState
    expect(state.status === 'mfa_required' && state.retryAfterSeconds).toBe(60)
    await coordinator.verifyMfa('123456')
    state = coordinator.currentState
    expect(state.status === 'mfa_required' && state.message).toMatch(/no está disponible/)
    expect(state.status === 'mfa_required' && state.diagnostic?.apiLocation).toBe('/api/v1/staff/auth/mfa/verify')
    expect(await coordinator.startMfaEnrollment()).toBeNull()
    state = coordinator.currentState
    expect(state.status === 'mfa_required' && state.message).toMatch(/ya está configurado/)
  })
})

describe('staff auth API contract for MFA roles', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('accepts only portal roles in a session', () => {
    expect(parseStaffSessionView(auditorSession).user.role).toBe('security_auditor')
    expect(parseStaffSessionView({ ...auditorSession, user: { ...auditorSession.user, role: 'admin' } }).user.role).toBe('admin')
    expect(() => parseStaffSessionView({ ...auditorSession, user: { ...auditorSession.user, role: 'user' } })).toThrow(StaffAuthApiError)
  })

  it('accepts only inline SVG QR codes and base32 secrets in enrollment data', () => {
    expect(parseStaffMfaEnrollment(enrollment).secret).toBe(enrollment.secret)
    for (const bad of [
      { ...enrollment, qr_svg_data_url: 'https://evil.example.test/qr.svg' },
      { ...enrollment, qr_svg_data_url: 'data:text/html;base64,PHNjcmlwdD4=' },
      { ...enrollment, qr_svg_data_url: 'data:image/svg+xml;base64,<svg onload=x>' },
      { ...enrollment, secret: 'not-base32!' },
      { ...enrollment, otpauth_uri: 'javascript:alert(1)' },
    ]) {
      expect(() => parseStaffMfaEnrollment(bad)).toThrow(StaffAuthApiError)
    }
  })

  it('maps HTTP 202 to a challenge and posts codes to the verify endpoint', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const path = String(input)
      if (path.endsWith('/login')) return jsonResponse(challenge, 202)
      if (path.endsWith('/mfa/verify')) return jsonResponse(auditorSession)
      if (path.endsWith('/mfa/cancel')) return new Response(null, { status: 204 })
      return jsonResponse(enrollment)
    })
    vi.stubGlobal('fetch', fetchMock)
    await expect(staffAuthApi.login('a@example.test', 'pw')).resolves.toEqual(challenge)
    await expect(staffAuthApi.startMfaEnrollment()).resolves.toEqual(enrollment)
    await expect(staffAuthApi.verifyMfa('123456')).resolves.toMatchObject({ user: { role: 'security_auditor' } })
    await expect(staffAuthApi.cancelMfa()).resolves.toBeUndefined()
    const verify = fetchMock.mock.calls.find(([input]) => String(input).endsWith('/mfa/verify')) as unknown as [string, RequestInit]
    expect(verify[1].method).toBe('POST')
    expect(verify[1].credentials).toBe('include')
    expect(JSON.parse(String(verify[1].body))).toEqual({ code: '123456' })
  })
})
