import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RequireStaffSession } from './RequireStaffSession'

type Status = 'authenticated' | 'restoring' | 'refreshing' | 'anonymous' | 'recoverable_error'

const auth = vi.hoisted(() => ({
  state: { status: 'restoring' } as { status: Status; message?: string },
}))

vi.mock('../../shared/auth/useStaffAuth', () => ({
  useStaffAuth: () => ({ state: auth.state, retry: vi.fn(), retryPendingLogout: vi.fn() }),
}))

function Page() {
  return (
    <MemoryRouter initialEntries={['/admin']}>
      <Routes>
        <Route path="/login" element={<p>login page</p>} />
        <Route
          path="/admin"
          element={
            <RequireStaffSession>
              <input aria-label="Motivo" />
            </RequireStaffSession>
          }
        />
      </Routes>
    </MemoryRouter>
  )
}

function setStatus(status: Status): void {
  auth.state = status === 'recoverable_error' ? { status, message: 'No disponible' } : { status }
}

describe('RequireStaffSession', () => {
  beforeEach(() => setStatus('restoring'))

  it('never renders protected content for a session that was not confirmed yet', () => {
    const { container } = render(<Page />)

    expect(screen.getByTestId('staff-auth-loading')).toBeInTheDocument()
    expect(container.querySelector('input')).toBeNull()
  })

  it('hides protected content while a confirmed session is re-confirmed, but keeps what was typed', async () => {
    setStatus('authenticated')
    const user = userEvent.setup()
    const { rerender } = render(<Page />)
    const field = screen.getByLabelText('Motivo')
    await user.type(field, 'motivo de prueba')

    setStatus('restoring')
    rerender(<Page />)

    // Hidden from people and assistive technology, and not interactive, with a loading notice on top.
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument()
    expect(screen.getByTestId('staff-auth-loading')).toBeInTheDocument()
    expect(screen.getByTestId('staff-protected-view')).toHaveAttribute('aria-hidden', 'true')
    expect(screen.getByTestId('staff-protected-view')).toHaveAttribute('inert')

    setStatus('authenticated')
    rerender(<Page />)

    expect(screen.getByLabelText('Motivo')).toBe(field)
    expect(field).toHaveValue('motivo de prueba')
    expect(screen.queryByTestId('staff-auth-loading')).not.toBeInTheDocument()
    expect(screen.getByTestId('staff-protected-view')).not.toHaveAttribute('inert')
  })

  it('holds the view through a renewal too', () => {
    setStatus('authenticated')
    const { rerender } = render(<Page />)

    setStatus('refreshing')
    rerender(<Page />)

    expect(screen.queryByRole('textbox')).not.toBeInTheDocument()
    expect(screen.getByTestId('staff-auth-loading')).toBeInTheDocument()
  })

  it('returns the focus to the field the person was in once the session is confirmed', async () => {
    setStatus('authenticated')
    const user = userEvent.setup()
    const { rerender } = render(<Page />)
    const field = screen.getByLabelText('Motivo')
    await user.click(field)
    expect(field).toHaveFocus()

    setStatus('restoring')
    rerender(<Page />)
    field.blur() // an inert view loses the focus in a real browser
    setStatus('authenticated')
    rerender(<Page />)

    expect(field).toHaveFocus()
  })

  it.each<Status>(['anonymous', 'recoverable_error'])(
    'removes the protected view for a definitive outcome (%s)',
    (outcome) => {
      setStatus('authenticated')
      const { rerender, container } = render(<Page />)
      setStatus('restoring')
      rerender(<Page />)

      setStatus(outcome)
      rerender(<Page />)

      expect(container.querySelector('input')).toBeNull()
      expect(screen.queryByTestId('staff-protected-view')).not.toBeInTheDocument()
    },
  )

  it('does not keep holding an old view after a denial and a new restoration', () => {
    setStatus('authenticated')
    const { rerender, container } = render(<Page />)
    setStatus('anonymous')
    rerender(<Page />)
    setStatus('restoring')
    rerender(<Page />)

    expect(container.querySelector('input')).toBeNull()
  })
})
