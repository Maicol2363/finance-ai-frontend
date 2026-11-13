import { createContext } from 'react'

export type StaffTheme = 'light' | 'dark'

export interface StaffThemeContextValue {
  theme: StaffTheme
  toggleTheme: () => void
}

export const StaffThemeContext = createContext<StaffThemeContextValue | null>(null)
