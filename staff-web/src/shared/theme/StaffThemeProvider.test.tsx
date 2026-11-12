import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { StaffThemeProvider, STAFF_THEME_STORAGE_KEY } from './StaffThemeProvider'
import { ThemeToggleButton } from './ThemeToggleButton'

function renderThemeToggle() {
  return render(
    <StaffThemeProvider>
      <ThemeToggleButton />
    </StaffThemeProvider>,
  )
}

describe('StaffThemeProvider', () => {
  beforeEach(() => {
    localStorage.clear()
    delete document.documentElement.dataset.theme
    document.documentElement.style.colorScheme = ''
  })

  afterEach(() => {
    localStorage.clear()
    delete document.documentElement.dataset.theme
    document.documentElement.style.colorScheme = ''
  })

  it('restores a valid saved theme and exposes the next action accessibly', async () => {
    localStorage.setItem(STAFF_THEME_STORAGE_KEY, 'dark')
    renderThemeToggle()

    await waitFor(() => expect(document.documentElement.dataset.theme).toBe('dark'))
    expect(document.documentElement.style.colorScheme).toBe('dark')
    expect(screen.getByRole('button', { name: 'Modo oscuro' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('Oscuro')).toBeInTheDocument()
  })

  it('toggles light and dark and stores the preference only under the theme key', async () => {
    const user = userEvent.setup()
    renderThemeToggle()

    const toggle = screen.getByRole('button', { name: 'Modo oscuro' })
    expect(toggle).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByText('Claro')).toBeInTheDocument()
    await user.click(toggle)

    await waitFor(() => expect(document.documentElement.dataset.theme).toBe('dark'))
    expect(document.documentElement.style.colorScheme).toBe('dark')
    expect(Object.entries(localStorage)).toEqual([[STAFF_THEME_STORAGE_KEY, 'dark']])
    expect(toggle).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('Oscuro')).toBeInTheDocument()

    await user.click(toggle)
    await waitFor(() => expect(document.documentElement.dataset.theme).toBe('light'))
    expect(Object.entries(localStorage)).toEqual([[STAFF_THEME_STORAGE_KEY, 'light']])
    expect(toggle).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByText('Claro')).toBeInTheDocument()
  })
})
