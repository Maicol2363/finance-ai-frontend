import { createContext } from 'react'
import type { StaffMfaEnrollmentView, StaffSessionView } from '../api/staffAuthApi'
import type { StaffAuthState } from './staffSessionCoordinator'

export interface StaffAuthContextValue {
  state: StaffAuthState
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  retry: () => Promise<void>
  retryPendingLogout: () => Promise<void>
  startMfaEnrollment: () => Promise<StaffMfaEnrollmentView | null>
  verifyMfa: (code: string) => Promise<void>
  cancelMfa: () => Promise<void>
  session: StaffSessionView | null
}

export const StaffAuthContext = createContext<StaffAuthContextValue | null>(null)
