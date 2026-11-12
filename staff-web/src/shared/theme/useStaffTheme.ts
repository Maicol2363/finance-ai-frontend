import { useContext } from 'react'
import { StaffThemeContext } from './StaffThemeContext'

export function useStaffTheme() {
  const context = useContext(StaffThemeContext)
  if (!context) throw new Error('useStaffTheme must be used within StaffThemeProvider')
  return context
}
