import { useCallback, useLayoutEffect, useMemo, useState, type ReactNode } from 'react'
import { StaffThemeContext, type StaffTheme } from './StaffThemeContext'

export const STAFF_THEME_STORAGE_KEY = 'finance_ai.theme_mode'

function initialTheme(): StaffTheme {
  try {
    const stored = window.localStorage.getItem(STAFF_THEME_STORAGE_KEY)
    if (stored === 'light' || stored === 'dark') return stored
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  } catch {
    return 'light'
  }
}

export function StaffThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<StaffTheme>(initialTheme)

  useLayoutEffect(() => {
    document.documentElement.dataset.theme = theme
    document.documentElement.style.colorScheme = theme
    document.querySelector('meta[name="theme-color"]')?.setAttribute(
      'content',
      theme === 'dark' ? '#171D22' : '#F5F7F6',
    )
  }, [theme])

  const toggleTheme = useCallback(() => {
    setTheme((current) => {
      const next = current === 'dark' ? 'light' : 'dark'
      try {
        window.localStorage.setItem(STAFF_THEME_STORAGE_KEY, next)
      } catch {
        // Theme changes remain usable when browser preference storage is unavailable.
      }
      return next
    })
  }, [])

  const value = useMemo(() => ({ theme, toggleTheme }), [theme, toggleTheme])
  return <StaffThemeContext.Provider value={value}>{children}</StaffThemeContext.Provider>
}
