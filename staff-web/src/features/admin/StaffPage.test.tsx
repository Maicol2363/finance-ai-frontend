import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { StaffPage } from './StaffPage'

const retry = vi.hoisted(() => vi.fn())

vi.mock('../../shared/auth/useStaffAuth', () => ({
  useStaffAuth: () => ({ session: { user: { id: 1, email: 'admin@example.test', role: 'admin' } }, retry }),
}))

const TOKEN = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ'
const invitation = {
  invitation_id: 4,
  email: 'new@example.com',
  role: 'support_agent',
  expires_at: '2026-11-17T12:00:00Z',
  activation_token: TOKEN,
}
const agent = {
  id: 5,
  email: 'agent@example.com',
  role: 'support_agent',
  status: 'active',
  registered_at: '2026-01-02T03:04:05Z',
  account_type: 'login_account',
  assignable_roles: ['security_auditor'],
}

function jsonResponse(body: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

describe('StaffPage invitations (ADM-03)', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })
  afterEach(() => vi.unstubAllGlobals())

  function inviteSection() {
    return screen.getByRole('region', { name: 'Invitar a una persona del personal' })
  }

  it('offers only the two staff roles and never an administrator option', () => {
    render(<StaffPage />)

    const options = within(inviteSection()).getAllByRole('option').map((option) => option.textContent)
    expect(options).toEqual(['Agente de soporte', 'Auditor de seguridad'])
    expect(inviteSection().textContent).toContain('Los administradores no se crean desde el portal')
  })

  it('validates the email locally', async () => {
    const user = userEvent.setup()
    render(<StaffPage />)

    await user.type(within(inviteSection()).getByLabelText('Correo electrónico'), 'no-valido')
    await user.click(within(inviteSection()).getByRole('button', { name: 'Crear invitación' }))

    expect(within(inviteSection()).getByRole('alert')).toHaveTextContent('correo electrónico completo')
    expect(fetch).not.toHaveBeenCalled()
  })

  it('shows the one-time activation link once, in the fragment, and discards it on demand', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(invitation, 201))
    const user = userEvent.setup()
    render(<StaffPage />)
    await user.type(within(inviteSection()).getByLabelText('Correo electrónico'), '  new@example.com ')
    await user.selectOptions(within(inviteSection()).getByLabelText('Rol inicial'), 'security_auditor')
    await user.click(within(inviteSection()).getByRole('button', { name: 'Crear invitación' }))

    const created = await screen.findByTestId('admin-invitation-created')
    const link = within(created).getByLabelText(/Enlace de activación/) as HTMLInputElement
    expect(link.value).toBe(`${window.location.origin}/activate#token=${TOKEN}`)
    expect(link.value).not.toContain('?')
    expect(created).toHaveTextContent('se muestra una sola vez')
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[0]![1]?.body))).toEqual({
      email: 'new@example.com',
      role: 'security_auditor',
    })

    await user.click(within(created).getByRole('button', { name: 'Ocultar y descartar' }))
    expect(screen.queryByTestId('admin-invitation-created')).not.toBeInTheDocument()
    expect(document.body.textContent).not.toContain(TOKEN)
  })

  it('never writes the token to storage or the address bar', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(invitation, 201))
    const user = userEvent.setup()
    render(<StaffPage />)
    await user.type(within(inviteSection()).getByLabelText('Correo electrónico'), 'new@example.com')
    await user.click(within(inviteSection()).getByRole('button', { name: 'Crear invitación' }))
    await screen.findByTestId('admin-invitation-created')

    expect(JSON.stringify({ ...localStorage })).not.toContain(TOKEN)
    expect(JSON.stringify({ ...sessionStorage })).not.toContain(TOKEN)
    expect(window.location.href).not.toContain(TOKEN)
  })

  it('copies the link when the clipboard is available and degrades gracefully otherwise', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse(invitation, 201))
    const user = userEvent.setup()
    // user-event installs its own clipboard stub in setup(); replace it afterwards.
    const writeText = vi.fn().mockResolvedValue(undefined)
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })
    render(<StaffPage />)
    await user.type(within(inviteSection()).getByLabelText('Correo electrónico'), 'new@example.com')
    await user.click(within(inviteSection()).getByRole('button', { name: 'Crear invitación' }))
    const created = await screen.findByTestId('admin-invitation-created')

    await user.click(within(created).getByRole('button', { name: 'Copiar enlace' }))
    expect(writeText).toHaveBeenCalledWith(`${window.location.origin}/activate#token=${TOKEN}`)
    expect(created).toHaveTextContent('Enlace copiado.')

    writeText.mockRejectedValueOnce(new Error('denied'))
    await user.click(within(created).getByRole('button', { name: 'Copiar enlace' }))
    expect(await within(created).findByText(/No se pudo copiar automáticamente/)).toBeInTheDocument()
  })

  it('explains a duplicate address without creating anything', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ code: 'staff_email_unavailable' }, 409, { 'X-Correlation-ID': 'c-dup' }))
    const user = userEvent.setup()
    render(<StaffPage />)
    await user.type(within(inviteSection()).getByLabelText('Correo electrónico'), 'dup@example.com')
    await user.click(within(inviteSection()).getByRole('button', { name: 'Crear invitación' }))

    expect(await screen.findByTestId('admin-error')).toHaveTextContent('Ya existe una cuenta o una invitación vigente')
    expect(screen.queryByTestId('admin-invitation-created')).not.toBeInTheDocument()
  })
})

describe('StaffPage role changes (ADM-04)', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })
  afterEach(() => vi.unstubAllGlobals())

  function roleSection() {
    return screen.getByRole('region', { name: 'Cambiar el rol de una persona del personal' })
  }

  async function load(user: ReturnType<typeof userEvent.setup>, id: string) {
    await user.type(within(roleSection()).getByLabelText('ID de la cuenta del personal'), id)
    await user.click(within(roleSection()).getByRole('button', { name: 'Consultar rol' }))
  }

  it('validates the account ID locally', async () => {
    const user = userEvent.setup()
    render(<StaffPage />)

    await load(user, 'abc')

    expect(within(roleSection()).getByRole('alert')).toHaveTextContent('ID de cuenta numérico válido')
    expect(fetch).not.toHaveBeenCalled()
  })

  it('changes between the two staff roles only after explicit confirmation', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(jsonResponse(agent))
      .mockResolvedValueOnce(jsonResponse({ ...agent, role: 'security_auditor', assignable_roles: ['support_agent'] }))
    const user = userEvent.setup()
    render(<StaffPage />)
    await load(user, '5')

    const result = await screen.findByTestId('admin-staff-result')
    expect(result).toHaveTextContent('Agente de soporte')
    const submit = within(result).getByRole('button', { name: 'Confirmar cambio de rol' })
    expect(submit).toBeDisabled()
    expect(within(result).getAllByRole('option').map((o) => o.textContent)).toEqual(['Auditor de seguridad'])
    await user.click(within(result).getByRole('checkbox'))
    await user.click(submit)

    await waitFor(() => expect(screen.getByTestId('admin-role-notice')).toHaveTextContent('Rol actualizado a «Auditor de seguridad»'))
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[1]![1]?.body))).toEqual({
      role: 'security_auditor',
      confirm: true,
    })
    expect(screen.getByTestId('admin-staff-result')).toHaveTextContent('Auditor de seguridad')
  })

  it('does not offer to change an administrator or the own account', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(jsonResponse({ ...agent, id: 9, role: 'admin', assignable_roles: [] }))
      .mockResolvedValueOnce(jsonResponse({ ...agent, id: 1 }))
    const user = userEvent.setup()
    render(<StaffPage />)

    await load(user, '9')
    expect(await screen.findByTestId('admin-role-locked')).toHaveTextContent('no se cambia desde el portal')
    expect(screen.queryByRole('button', { name: 'Confirmar cambio de rol' })).not.toBeInTheDocument()

    await user.clear(within(roleSection()).getByLabelText('ID de la cuenta del personal'))
    await user.type(within(roleSection()).getByLabelText('ID de la cuenta del personal'), '1')
    await user.click(within(roleSection()).getByRole('button', { name: 'Consultar rol' }))
    expect(await screen.findByText('No puedes cambiar tu propio rol.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Confirmar cambio de rol' })).not.toBeInTheDocument()
  })

  it('reports a refused change and keeps the confirmation available', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(jsonResponse(agent))
      .mockResolvedValueOnce(jsonResponse({ code: 'role_change_not_allowed' }, 409, { 'X-Correlation-ID': 'c-role' }))
    const user = userEvent.setup()
    render(<StaffPage />)
    await load(user, '5')
    const result = await screen.findByTestId('admin-staff-result')
    await user.click(within(result).getByRole('checkbox'))
    await user.click(within(result).getByRole('button', { name: 'Confirmar cambio de rol' }))

    expect(await screen.findByTestId('admin-error')).toHaveTextContent('Solo se puede alternar el rol')
    expect(screen.getByTestId('admin-staff-result')).toHaveTextContent('Agente de soporte')
  })

  it('shows a safe not-found message for an unknown staff ID', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ code: 'account_not_found' }, 404))
    const user = userEvent.setup()
    render(<StaffPage />)

    await load(user, '404')

    expect(await screen.findByTestId('admin-error')).toHaveTextContent('No hay ninguna cuenta de acceso')
  })
})
