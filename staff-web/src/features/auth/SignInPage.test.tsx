import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router'
import { describe, expect, it, vi } from 'vitest'
import { SignInPage } from './SignInPage'
import { StaffAuthContext, type StaffAuthContextValue } from '../../shared/auth/staffAuthContext'
import type { StaffAuthState } from '../../shared/auth/staffSessionCoordinator'
import { StaffThemeProvider } from '../../shared/theme/StaffThemeProvider'

const validSession = {
  user: { id: 42, email: 'agent@example.test', role: 'support_agent' as const },
  access_expires_at: '2026-11-11T15:30:00Z',
  renewable_expires_at: '2026-11-12T15:00:00Z',
  absolute_expires_at: '2026-11-18T15:00:00Z',
}

function LocationProbe() {
  const location = useLocation()
  return <p data-testid="current-location">{`${location.pathname}${location.search}`}</p>
}

function contextValue(state: StaffAuthState): StaffAuthContextValue {
  return {
    state,
    session: state.status === 'authenticated' ? state.session : null,
    login: vi.fn().mockResolvedValue(undefined),
    logout: vi.fn().mockResolvedValue(undefined),
    retry: vi.fn().mockResolvedValue(undefined),
    retryPendingLogout: vi.fn().mockResolvedValue(undefined),
  }
}

function renderPage(value: StaffAuthContextValue, entry = '/login') {
  return render(
    <StaffThemeProvider>
      <StaffAuthContext.Provider value={value}>
        <MemoryRouter initialEntries={[entry]}>
          <LocationProbe />
          <Routes>
            <Route element={<SignInPage />} path="/login" />
            <Route element={<p data-testid="support-destination">Support destination</p>} path="/support/*" />
            <Route element={<p data-testid="unknown-destination">Unknown destination</p>} path="*" />
          </Routes>
        </MemoryRouter>
      </StaffAuthContext.Provider>
    </StaffThemeProvider>,
  )
}

describe('SignInPage', () => {
  it('associates the labelled fields with a keyboard-submittable form', async () => {
    const value = contextValue({ status: 'anonymous' })
    const user = userEvent.setup()
    renderPage(value)

    const email = screen.getByRole('textbox', { name: 'Correo electrónico' })
    const password = screen.getByLabelText('Contraseña')
    expect(email).toHaveAttribute('autocomplete', 'username')
    expect(password).toHaveAttribute('autocomplete', 'current-password')
    expect(screen.getByTestId('staff-sign-in-form')).toHaveAttribute('aria-labelledby', 'staff-sign-in-heading')
    expect(screen.getByTestId('staff-brand-logo')).toHaveAttribute('src', '/finance-ai-app-icon.png')

    await user.type(email, 'agent@example.test')
    await user.type(password, 'example-only-password')
    await user.keyboard('{Enter}')
    await waitFor(() => expect(value.login).toHaveBeenCalledWith('agent@example.test', 'example-only-password'))
  })

  it('shows only the safe generic credential message supplied by auth state', () => {
    renderPage(contextValue({ status: 'anonymous', message: 'No se pudo verificar el correo electrónico o la contraseña.' }))

    expect(screen.getByRole('alert')).toHaveTextContent('No se pudo verificar el correo electrónico o la contraseña.')
    expect(screen.queryByText(/invalid_credentials|request body|example-only-password/i)).not.toBeInTheDocument()
  })

  it('respects Retry-After and enables submit when the wait elapses', async () => {
    vi.useFakeTimers()
    try {
      renderPage(contextValue({ status: 'recoverable_error', message: 'Demasiados intentos.', retryAfterSeconds: 2 }))

      const submit = screen.getByRole('button', { name: 'Vuelve a intentarlo en 2 s' })
      expect(submit).toBeDisabled()
      await act(async () => vi.advanceTimersByTimeAsync(1000))
      expect(screen.getByRole('button', { name: 'Vuelve a intentarlo en 1 s' })).toBeDisabled()
      await act(async () => vi.advanceTimersByTimeAsync(1000))
      expect(screen.getByRole('button', { name: 'Iniciar sesión' })).toBeEnabled()
    } finally {
      vi.useRealTimers()
    }
  })

  it('provides an explicit retry action for recoverable session failures', async () => {
    const value = contextValue({ status: 'recoverable_error', message: 'No se pudo conectar con el servicio. Inténtalo de nuevo.' })
    const user = userEvent.setup()
    renderPage(value)

    await user.click(screen.getByRole('button', { name: 'Comprobar sesión de nuevo' }))
    expect(value.retry).toHaveBeenCalledOnce()
    expect(screen.getByRole('alert')).toHaveTextContent('No se pudo conectar con el servicio. Inténtalo de nuevo.')
  })

  it('keeps the user blocked while logout needs server confirmation', async () => {
    const value = contextValue({ status: 'logout_pending', message: 'No se pudo confirmar el cierre de sesión. Vuelve a intentarlo para completarlo.' })
    const user = userEvent.setup()
    renderPage(value)

    expect(screen.getByRole('heading', { name: 'Confirma el cierre de sesión' })).toBeInTheDocument()
    expect(screen.queryByTestId('staff-sign-in-form')).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Reintentar cierre de sesión' }))
    expect(value.retryPendingLogout).toHaveBeenCalledOnce()
  })

  it('returns an authenticated user to the original internal Support route', () => {
    renderPage(contextValue({ status: 'authenticated', session: validSession }), {
      pathname: '/login',
      state: { from: '/support/tickets' },
    } as never)

    expect(screen.getByTestId('support-destination')).toBeInTheDocument()
    expect(screen.getByTestId('current-location')).toHaveTextContent('/support/tickets')
  })

  it('does not navigate to an external or unsupported return destination', () => {
    renderPage(contextValue({ status: 'authenticated', session: validSession }), {
      pathname: '/login',
      state: { from: 'https://evil.example.test' },
    } as never)

    expect(screen.getByTestId('support-destination')).toBeInTheDocument()
    expect(screen.getByTestId('current-location')).toHaveTextContent('/support')
  })
})
