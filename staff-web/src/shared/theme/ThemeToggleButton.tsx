import { useStaffTheme } from './useStaffTheme'

export function ThemeToggleButton() {
  const { theme, toggleTheme } = useStaffTheme()

  return (
    <button
      aria-label="Modo oscuro"
      aria-pressed={theme === 'dark'}
      className="theme-toggle-button"
      data-testid="staff-theme-toggle"
      onClick={toggleTheme}
      title="Cambiar el modo de color"
      type="button"
    >
      <span aria-hidden="true" className="theme-toggle-icon">{theme === 'dark' ? '☾' : '☀'}</span>
      <span className="theme-toggle-label">{theme === 'dark' ? 'Oscuro' : 'Claro'}</span>
    </button>
  )
}
