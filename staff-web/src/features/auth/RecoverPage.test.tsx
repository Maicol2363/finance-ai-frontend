import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router'
import { describe, expect, it, vi } from 'vitest'
import { StaffAuthContext, type StaffAuthContextValue } from '../../shared/auth/staffAuthContext'
import type { StaffAuthState } from '../../shared/auth/staffSessionCoordinator'
import { StaffThemeProvider } from '../../shared/theme/StaffThemeProvider'
import { RecoverPage } from './RecoverPage'

function contextValue(state: StaffAuthState, resetMfa = vi.fn().mockResolvedValue(undefined)): StaffAuthContextValue {
  return {
    state,
    session: state.status === 'authenticated' ? state.session : null,
    login: vi.fn(),
    logout: vi.fn(),
    retry: vi.fn(),
    retryPendingLogout: vi.fn(),
    startMfaEnrollment: vi.fn(),
    verifyMfa: vi.fn(),
    cancelMfa: vi.fn(),
    resetMfa,
  }
}

function renderPage(value: StaffAuthContextValue) {
  return render(
    <StaffThemeProvider>
      <StaffAuthContext.Provider value={value}>
        <MemoryRouter initialEntries={['/recover']}>
          <Routes>
            <Route element={<RecoverPage />} path="/recover" />
            <Route element={<p data-testid="login-route">login</p>} path="/login" />
          </Routes>
        </MemoryRouter>
      </StaffAuthContext.Provider>
    </StaffThemeProvider>,
  )
}

async function fill(user: ReturnType<typeof userEvent.setup>, proofValue: string) {
  await user.type(screen.getByLabelText('Correo electrónico'), 'admin@example.test')
  await user.type(screen.getByLabelText('Contraseña'), 'example-only-password')
  await user.type(screen.getByRole('textbox', { name: /^Código de recuperación$|^Código de 6 dígitos$/ }), proofValue)
}

describe('RecoverPage (SEC-01)', () => {
  it('validates the proof format locally', async () => {
    const value = contextValue({ status: 'anonymous' })
    const user = userEvent.setup()
    renderPage(value)

    await fill(user, 'corto')
    await user.click(screen.getByRole('button', { name: 'Verificar y continuar' }))

    expect(screen.getByRole('alert')).toHaveTextContent('código de recuperación completo')
    expect(value.resetMfa).not.toHaveBeenCalled()
  })

  it('sends the recovery code with the password and clears the sensitive fields', async () => {
    const value = contextValue({ status: 'anonymous' })
    const user = userEvent.setup()
    renderPage(value)

    await fill(user, 'abcd-efgh-ijkl-mnop')
    await user.click(screen.getByRole('button', { name: 'Verificar y continuar' }))

    expect(value.resetMfa).toHaveBeenCalledWith('admin@example.test', 'example-only-password', {
      recoveryCode: 'abcd-efgh-ijkl-mnop',
    })
    expect(screen.getByLabelText('Contraseña')).toHaveValue('')
    expect(screen.getByRole('textbox', { name: 'Código de recuperación' })).toHaveValue('')
  })

  it('supports replacing the authenticator with its current six-digit code', async () => {
    const value = contextValue({ status: 'anonymous' })
    const user = userEvent.setup()
    renderPage(value)
    await user.click(screen.getByRole('radio', { name: 'Código de mi autenticador actual' }))

    await fill(user, '123456')
    await user.click(screen.getByRole('button', { name: 'Verificar y continuar' }))

    expect(value.resetMfa).toHaveBeenCalledWith('admin@example.test', 'example-only-password', { code: '123456' })
  })

  it('continues on the sign-in screen once the server opens an enrollment challenge', () => {
    renderPage(
      contextValue({
        status: 'mfa_required',
        challenge: { status: 'mfa_required', enrollment_required: true, challenge_expires_at: '2026-11-15T12:00:00Z' },
        pending: false,
      }),
    )

    expect(screen.getByTestId('login-route')).toBeInTheDocument()
  })

  it('shows the generic failure message without revealing which input was wrong', () => {
    renderPage(contextValue({ status: 'anonymous', message: 'No se pudo verificar la recuperación.' }))

    expect(screen.getByTestId('staff-recover-message')).toHaveTextContent('No se pudo verificar la recuperación.')
  })

  it('offers the operator path when the person has no proof at all', () => {
    renderPage(contextValue({ status: 'anonymous' }))

    expect(screen.getByText(/Pide a un administrador del sistema que restablezca/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Volver al inicio de sesión' })).toHaveAttribute('href', '/login')
  })
})
