import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { StaffThemeProvider } from '../../shared/theme/StaffThemeProvider'
import { ActivatePage } from './ActivatePage'
import { readActivationToken } from './activationToken'

const TOKEN = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ'
const PASSWORD = 'a-long-and-unusual-passphrase'

function renderPage() {
  return render(
    <StaffThemeProvider>
      <MemoryRouter>
        <ActivatePage />
      </MemoryRouter>
    </StaffThemeProvider>,
  )
}

function problem(code: string, status: number, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify({ code }), { status, headers: { 'Content-Type': 'application/json', ...headers } })
}

describe('readActivationToken', () => {
  it('accepts only a well-formed token in the fragment', () => {
    expect(readActivationToken(`#token=${TOKEN}`)).toBe(TOKEN)
    expect(readActivationToken('')).toBeNull()
    expect(readActivationToken('#token=short')).toBeNull()
    expect(readActivationToken(`#other=${TOKEN}`)).toBeNull()
    expect(readActivationToken(`#token=${TOKEN}extra`)).toBeNull()
  })
})

describe('ActivatePage (ADM-03)', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    window.history.pushState({}, '', `/activate#token=${TOKEN}`)
  })
  afterEach(() => vi.unstubAllGlobals())

  it('removes the token from the address bar right after reading it', async () => {
    renderPage()

    await screen.findByRole('heading', { name: 'Elige tu contraseña' })
    expect(window.location.hash).toBe('')
    expect(window.location.href).not.toContain(TOKEN)
    expect(document.body.textContent).not.toContain(TOKEN)
  })

  it('shows a generic invalid-link page when there is no usable token', async () => {
    window.history.pushState({}, '', '/activate')
    renderPage()

    expect(await screen.findByTestId('staff-activate-invalid')).toHaveTextContent('no es válido o ya se usó')
    expect(screen.queryByLabelText('Contraseña nueva')).not.toBeInTheDocument()
  })

  it('checks the password locally before calling the server', async () => {
    const user = userEvent.setup()
    renderPage()

    await user.type(await screen.findByLabelText('Contraseña nueva'), 'short')
    await user.type(screen.getByLabelText('Confirma la contraseña'), 'short')
    await user.click(screen.getByRole('button', { name: 'Activar cuenta' }))
    expect(screen.getByTestId('staff-activate-message')).toHaveTextContent('entre 8 y 128 caracteres')

    await user.clear(screen.getByLabelText('Contraseña nueva'))
    await user.type(screen.getByLabelText('Contraseña nueva'), PASSWORD)
    await user.click(screen.getByRole('button', { name: 'Activar cuenta' }))
    expect(screen.getByTestId('staff-activate-message')).toHaveTextContent('no coinciden')
    expect(fetch).not.toHaveBeenCalled()
  })

  it('activates with the token and chosen password, then points to sign-in without a session', async () => {
    vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 204 }))
    const user = userEvent.setup()
    renderPage()
    await user.type(await screen.findByLabelText('Contraseña nueva'), PASSWORD)
    await user.type(screen.getByLabelText('Confirma la contraseña'), PASSWORD)
    await user.click(screen.getByRole('button', { name: 'Activar cuenta' }))

    expect(await screen.findByTestId('staff-activate-success')).toBeInTheDocument()
    const [url, init] = vi.mocked(fetch).mock.calls[0]!
    expect(String(url)).toBe('/api/v1/staff/auth/activate')
    expect(JSON.parse(String(init?.body))).toEqual({ token: TOKEN, password: PASSWORD, password_confirmation: PASSWORD })
    expect(new Headers(init?.headers).get('X-Staff-Request')).toBe('1')
    expect(screen.getByRole('link', { name: 'Ir a iniciar sesión' })).toHaveAttribute('href', '/login')
    expect(document.body.textContent).not.toContain(PASSWORD)
    expect(document.body.textContent).not.toContain(TOKEN)
  })

  it('shows one generic message for expired, replayed or unknown links and removes the form', async () => {
    vi.mocked(fetch).mockResolvedValue(problem('activation_invalid', 400, { 'X-Correlation-ID': 'c-act' }))
    const user = userEvent.setup()
    renderPage()
    await user.type(await screen.findByLabelText('Contraseña nueva'), PASSWORD)
    await user.type(screen.getByLabelText('Confirma la contraseña'), PASSWORD)
    await user.click(screen.getByRole('button', { name: 'Activar cuenta' }))

    expect(await screen.findByTestId('staff-activate-invalid')).toHaveTextContent('Este enlace no es válido, venció o ya se usó')
    expect(screen.queryByLabelText('Contraseña nueva')).not.toBeInTheDocument()
  })

  it('keeps the form for a rejected password so the person can choose another', async () => {
    vi.mocked(fetch).mockResolvedValue(problem('activation_password_invalid', 422))
    const user = userEvent.setup()
    renderPage()
    await user.type(await screen.findByLabelText('Contraseña nueva'), 'password123')
    await user.type(screen.getByLabelText('Confirma la contraseña'), 'password123')
    await user.click(screen.getByRole('button', { name: 'Activar cuenta' }))

    expect(await screen.findByTestId('staff-activate-message')).toHaveTextContent('no es aceptable')
    expect(screen.getByLabelText('Contraseña nueva')).toHaveValue('')
  })

  it('reports rate limiting with the wait time', async () => {
    vi.mocked(fetch).mockResolvedValue(problem('mfa_rate_limited', 429, { 'Retry-After': '45' }))
    const user = userEvent.setup()
    renderPage()
    await user.type(await screen.findByLabelText('Contraseña nueva'), PASSWORD)
    await user.type(screen.getByLabelText('Confirma la contraseña'), PASSWORD)
    await user.click(screen.getByRole('button', { name: 'Activar cuenta' }))

    expect(await screen.findByTestId('staff-activate-message')).toHaveTextContent('45 segundos')
  })
})
