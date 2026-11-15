import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { SecurityPage } from './SecurityPage'

const CODES = Array.from({ length: 10 }, (_, index) => `AAAA-BBBB-CCCC-DDD${'ABCDEFGHIJ'[index]}`)

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

describe('SecurityPage recovery codes (SEC-01)', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })
  afterEach(() => vi.unstubAllGlobals())

  it('requires the password, shows the codes once and never stores them', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ recovery_codes: CODES }))
    const user = userEvent.setup()
    render(<SecurityPage />)

    const submit = screen.getByRole('button', { name: 'Generar códigos' })
    expect(submit).toBeDisabled()
    await user.type(screen.getByLabelText('Confirma tu contraseña'), 'example-only-password')
    await user.click(submit)

    const codes = await screen.findByTestId('admin-recovery-codes')
    expect(codes).toHaveTextContent('No se volverán a mostrar')
    for (const code of CODES) expect(codes).toHaveTextContent(code)
    expect(screen.getByLabelText('Confirma tu contraseña')).toHaveValue('')
    expect(JSON.parse(String(vi.mocked(fetch).mock.calls[0]![1]?.body))).toEqual({ password: 'example-only-password' })
    expect(String(vi.mocked(fetch).mock.calls[0]![0])).toBe('/api/v1/staff/auth/mfa/recovery-codes')
    expect(JSON.stringify({ ...localStorage, ...sessionStorage })).not.toContain(CODES[0])

    await user.click(screen.getByRole('button', { name: 'Ocultar y descartar' }))
    expect(screen.queryByTestId('admin-recovery-codes')).not.toBeInTheDocument()
    expect(document.body.textContent).not.toContain(CODES[0])
  })

  it('removes the codes when the section is left', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ recovery_codes: CODES }))
    const user = userEvent.setup()
    const { unmount } = render(<SecurityPage />)
    await user.type(screen.getByLabelText('Confirma tu contraseña'), 'example-only-password')
    await user.click(screen.getByRole('button', { name: 'Generar códigos' }))
    await screen.findByTestId('admin-recovery-codes')

    unmount()

    expect(document.body.textContent).not.toContain(CODES[0])
  })

  it('reports a wrong password without showing any code', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ code: 'password_confirmation_invalid' }, 403))
    const user = userEvent.setup()
    render(<SecurityPage />)
    await user.type(screen.getByLabelText('Confirma tu contraseña'), 'wrong')
    await user.click(screen.getByRole('button', { name: 'Generar códigos' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('La contraseña no es correcta.')
    expect(screen.queryByTestId('admin-recovery-codes')).not.toBeInTheDocument()
  })

  it('rejects a malformed server response instead of rendering it', async () => {
    vi.mocked(fetch).mockResolvedValue(jsonResponse({ recovery_codes: ['<script>alert(1)</script>'] }))
    const user = userEvent.setup()
    render(<SecurityPage />)
    await user.type(screen.getByLabelText('Confirma tu contraseña'), 'example-only-password')
    await user.click(screen.getByRole('button', { name: 'Generar códigos' }))

    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('No se pudieron generar'))
    expect(document.body.innerHTML).not.toContain('<script>')
  })
})
