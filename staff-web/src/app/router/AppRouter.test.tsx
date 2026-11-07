import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { AppRouter } from './AppRouter'

function renderApp() {
  return render(<AppRouter />)
}

describe('staff portal foundation', () => {
  it('shows the shared layout and clearly marks role workspaces as pending', () => {
    renderApp()
    expect(screen.getByRole('complementary', { name: 'Staff navigation' })).toBeInTheDocument()
    expect(screen.getByRole('navigation')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Ready for implementation' })).toBeInTheDocument()
    expect(screen.getByText(/does not display live data/i)).toBeInTheDocument()
  })

  it('navigates to the sign-in placeholder without simulating authentication', async () => {
    const user = userEvent.setup()
    renderApp()
    await user.click(screen.getByRole('link', { name: 'Sign in' }))
    expect(screen.getByRole('heading', { name: 'Sign-in is not connected' })).toBeInTheDocument()
    expect(screen.getByText(/does not yet define a secure browser-session contract/i)).toBeInTheDocument()
  })

  it('navigates between the three role workspaces', async () => {
    const user = userEvent.setup()
    renderApp()

    await user.click(screen.getByRole('link', { name: 'Support' }))
    expect(screen.getByRole('heading', { name: 'Customer support' })).toBeInTheDocument()
    await user.click(screen.getByRole('link', { name: 'Administration' }))
    expect(screen.getByRole('heading', { name: 'Administration' })).toBeInTheDocument()
    await user.click(screen.getByRole('link', { name: 'Security audit' }))
    expect(screen.getByRole('heading', { name: 'Security audit' })).toBeInTheDocument()
  })
})
