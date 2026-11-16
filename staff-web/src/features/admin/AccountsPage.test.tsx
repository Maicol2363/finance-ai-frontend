import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AccountsPage } from './AccountsPage'

const retry = vi.hoisted(() => vi.fn())

vi.mock('../../shared/auth/useStaffAuth', () => ({
  useStaffAuth: () => ({ session: { user: { id: 1, email: 'admin@example.test', role: 'admin' } }, retry }),
}))

const base = {
  id: 7,
  email: 'customer@example.com',
  role: 'user',
  status: 'active',
  registered_at: '2026-01-02T03:04:05Z',
  account_type: 'login_account',
  suspension: null,
}

function jsonResponse(body: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

function problem(code: string, status: number, correlation = 'corr-9'): Response {
  return jsonResponse({ code }, status, { 'X-Correlation-ID': correlation })
}

describe('AccountsPage (ADM-01, ADM-02)', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    retry.mockReset()
  })
  afterEach(() => vi.unstubAllGlobals())

  async function search(user: ReturnType<typeof userEvent.setup>, text: string, by: 'email' | 'id' = 'email') {
    if (by === 'id') await user.click(screen.getByRole('radio', { name: 'ID de cuenta' }))
    await user.type(screen.getByRole('textbox'), text)
    await user.click(screen.getByRole('button', { name: 'Buscar cuenta' }))
  }

  it('validates the lookup input before any request is sent', async () => {
    const user = userEvent.setup()
    render(<AccountsPage />)

    await user.click(screen.getByRole('button', { name: 'Buscar cuenta' }))
    expect(screen.getByRole('alert')).toHaveTextContent('correo electrónico completo')

    await user.type(screen.getByRole('textbox'), 'sin-arroba')
    await user.click(screen.getByRole('button', { name: 'Buscar cuenta' }))
    expect(screen.getByRole('alert')).toHaveTextContent('correo electrónico completo')

    await user.click(screen.getByRole('radio', { name: 'ID de cuenta' }))
    for (const bad of ['0', 'abc', '12 34', '99999999999999999999']) {
      await user.clear(screen.getByRole('textbox'))
      await user.type(screen.getByRole('textbox'), bad)
      await user.click(screen.getByRole('button', { name: 'Buscar cuenta' }))
      expect(screen.getByRole('alert')).toHaveTextContent('ID de cuenta numérico válido')
    }
    expect(fetch).not.toHaveBeenCalled()
  })

  it('shows only the allowlisted login-account metadata, labelled as a login account', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(base))
    const user = userEvent.setup()
    render(<AccountsPage />)

    await search(user, ' Customer@Example.com ')

    const result = await screen.findByTestId('admin-account-result')
    expect(within(result).getByRole('heading', { name: 'customer@example.com' })).toBeInTheDocument()
    expect(result).toHaveTextContent('cuenta de acceso (login), no una cuenta financiera')
    expect(result).toHaveTextContent('Cliente')
    expect(result).toHaveTextContent('Activa')
    expect(String(vi.mocked(fetch).mock.calls[0]![0])).toBe('/api/v1/staff/admin/accounts/lookup')
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[0]![1]?.body))).toEqual({ email: 'Customer@Example.com' })
    expect(String(vi.mocked(fetch).mock.calls[0]![0])).not.toMatch(/customer/i)
    expect(result.textContent).not.toMatch(/saldo|balance|contraseña|password|token/i)
  })

  it('looks up by numeric ID', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(base))
    const user = userEvent.setup()
    render(<AccountsPage />)

    await search(user, '7', 'id')

    expect(await screen.findByTestId('admin-account-result')).toBeInTheDocument()
    expect(String(vi.mocked(fetch).mock.calls[0]![0])).toBe('/api/v1/staff/admin/accounts/lookup')
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[0]![1]?.body))).toEqual({ id: 7 })
  })

  it('shows a safe not-found message with the correlation reference and no result', async () => {
    vi.mocked(fetch).mockResolvedValue(problem('account_not_found', 404, 'corr-nf'))
    const user = userEvent.setup()
    render(<AccountsPage />)

    await search(user, 'nobody@example.com')

    const alert = await screen.findByTestId('admin-error')
    expect(alert).toHaveTextContent('No hay ninguna cuenta de acceso con ese dato.')
    expect(alert).toHaveTextContent('corr-nf')
    expect(screen.queryByTestId('admin-account-result')).not.toBeInTheDocument()
  })

  it('requires a reason and an explicit confirmation before suspending, then shows the new state', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse(base)).mockResolvedValueOnce(
      jsonResponse({
        ...base,
        status: 'suspended',
        suspension: { reason: 'fraude confirmado', suspended_at: '2026-11-15T10:00:00Z', suspended_by_user_id: 1 },
      }),
    )
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')
    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }))

    const confirm = screen.getByRole('button', { name: 'Confirmar suspensión' })
    expect(confirm).toBeDisabled()
    await user.type(screen.getByLabelText(/Motivo de la suspensión/), '   ')
    await user.click(screen.getByRole('checkbox'))
    expect(confirm).toBeDisabled()
    await user.type(screen.getByLabelText(/Motivo de la suspensión/), '  fraude confirmado  ')
    expect(confirm).toBeEnabled()
    await user.click(confirm)

    await waitFor(() => expect(screen.getByTestId('admin-suspension-detail')).toHaveTextContent('fraude confirmado'))
    expect(screen.getByTestId('admin-accounts-notice')).toHaveTextContent('Cuenta suspendida')
    const [url, init] = vi.mocked(fetch).mock.calls[1]!
    expect(String(url)).toBe('/api/v1/staff/admin/accounts/7/suspend')
    expect(JSON.parse(String(init?.body))).toEqual({ reason: 'fraude confirmado', confirm: true })
    expect(screen.queryByTestId('admin-confirm-panel')).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Reactivar cuenta' })).toBeInTheDocument()
  })

  it('lets the administrator cancel a pending suspension without sending anything', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(base))
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')

    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }))
    await user.click(screen.getByRole('button', { name: 'Cancelar' }))

    expect(screen.queryByTestId('admin-confirm-panel')).not.toBeInTheDocument()
    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it('reactivates with confirmation and explains that old sessions are not restored', async () => {
    const suspended = {
      ...base,
      status: 'suspended',
      suspension: { reason: 'revisión', suspended_at: '2026-11-15T10:00:00Z', suspended_by_user_id: 1 },
    }
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse(suspended)).mockResolvedValueOnce(jsonResponse(base))
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')

    await user.click(await screen.findByRole('button', { name: 'Reactivar cuenta' }))
    expect(screen.getByRole('button', { name: 'Confirmar reactivación' })).toBeDisabled()
    await user.click(screen.getByRole('checkbox'))
    await user.click(screen.getByRole('button', { name: 'Confirmar reactivación' }))

    await waitFor(() => expect(screen.getByTestId('admin-accounts-notice')).toHaveTextContent('sesiones anteriores no se restauran'))
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[1]![1]?.body))).toEqual({ confirm: true })
    expect(screen.queryByTestId('admin-suspension-detail')).not.toBeInTheDocument()
  })

  it('offers no suspension for the administrator’s own account', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ ...base, id: 1, email: 'admin@example.test', role: 'admin' }))
    const user = userEvent.setup()
    render(<AccountsPage />)

    await search(user, 'admin@example.test')

    expect(await screen.findByTestId('admin-own-account')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Suspender cuenta' })).not.toBeInTheDocument()
  })

  it.each([
    ['admin_self_action_denied', /propia cuenta/],
    ['last_active_admin_protected', /sin un administrador activo/],
    ['audit_unavailable', /no se aplicó/],
  ])('keeps the panel open and explains the %s refusal', async (code, message) => {
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse(base)).mockResolvedValueOnce(problem(code, 409))
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')
    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }))
    await user.type(screen.getByLabelText(/Motivo de la suspensión/), 'motivo')
    await user.click(screen.getByRole('checkbox'))
    await user.click(screen.getByRole('button', { name: 'Confirmar suspensión' }))

    expect(await screen.findByTestId('admin-error')).toHaveTextContent(message)
    expect(screen.getByTestId('admin-confirm-panel')).toBeInTheDocument()
    expect(screen.getByTestId('admin-account-result')).toHaveTextContent('Activa')
  })

  it('keeps what was typed when the access credential expired, asks the coordinator and lets the person resend', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(jsonResponse(base))
      .mockResolvedValueOnce(problem('access_expired', 401))
      .mockResolvedValueOnce(jsonResponse({ ...base, status: 'suspended', suspension: null }))
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')
    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }))
    await user.type(screen.getByLabelText(/Motivo de la suspensión/), 'motivo')
    await user.click(screen.getByRole('checkbox'))
    await user.click(screen.getByRole('button', { name: 'Confirmar suspensión' }))

    const notice = await screen.findByTestId('admin-error')
    expect(notice).toHaveTextContent('Tu sesión se está renovando')
    expect(notice).toHaveTextContent('access_expired')
    expect(retry).toHaveBeenCalledTimes(1)
    expect(screen.getByLabelText(/Motivo de la suspensión/)).toHaveValue('motivo')

    await user.click(screen.getByRole('button', { name: 'Confirmar suspensión' }))
    await waitFor(() => expect(screen.queryByTestId('admin-confirm-panel')).not.toBeInTheDocument())
    expect(screen.getByTestId('admin-account-result')).toHaveTextContent('Suspendida')
  })

  it('does not start a new lookup while a change is pending, so a late result cannot replace another account', async () => {
    let finish: ((response: Response) => void) | undefined
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse(base)).mockImplementationOnce(
      () => new Promise<Response>((resolve) => { finish = resolve }),
    )
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')
    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }))
    await user.type(screen.getByLabelText(/Motivo de la suspensión/), 'motivo')
    await user.click(screen.getByRole('checkbox'))
    await user.click(screen.getByRole('button', { name: 'Confirmar suspensión' }))
    expect(await screen.findByRole('button', { name: 'Aplicando…' })).toBeDisabled()

    expect(screen.getByRole('button', { name: 'Buscar cuenta' })).toBeDisabled()
    await user.type(screen.getByLabelText('Correo electrónico exacto'), 'otra@example.com{Enter}')
    expect(fetch).toHaveBeenCalledTimes(2)

    finish?.(jsonResponse({ ...base, status: 'suspended', suspension: null }))
    await waitFor(() => expect(screen.getByTestId('admin-account-result')).toHaveTextContent('Suspendida'))
    expect(screen.getByRole('button', { name: 'Buscar cuenta' })).toBeEnabled()
  })

  it('does not send a second suspension while one is in flight', async () => {
    let finish: ((response: Response) => void) | undefined
    vi.mocked(fetch).mockResolvedValueOnce(jsonResponse(base)).mockImplementationOnce(
      () => new Promise<Response>((resolve) => { finish = resolve }),
    )
    const user = userEvent.setup()
    render(<AccountsPage />)
    await search(user, 'customer@example.com')
    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }))
    await user.type(screen.getByLabelText(/Motivo de la suspensión/), 'motivo')
    await user.click(screen.getByRole('checkbox'))
    await user.click(screen.getByRole('button', { name: 'Confirmar suspensión' }))

    expect(await screen.findByRole('button', { name: 'Aplicando…' })).toBeDisabled()
    expect(fetch).toHaveBeenCalledTimes(2)
    finish?.(jsonResponse({ ...base, status: 'suspended', suspension: null }))
  })
})
