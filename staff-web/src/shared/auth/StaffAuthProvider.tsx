import { useEffect, useMemo, useState, type ReactNode } from 'react'
import type { StaffSessionView } from '../api/staffAuthApi'
import { StaffSessionCoordinator, type StaffAuthState } from './staffSessionCoordinator'
import { StaffAuthContext, type StaffAuthContextValue } from './staffAuthContext'

interface StaffAuthProviderProps {
  children: ReactNode
}

export function StaffAuthProvider({ children }: StaffAuthProviderProps) {
  const [coordinator] = useState(() => new StaffSessionCoordinator())
  const [state, setState] = useState<StaffAuthState>(coordinator.currentState)
  // The last confirmed session, kept only while that session is being re-confirmed
  // (restoring/refreshing). The protected view is hidden and inert during that time but stays
  // mounted, and the role gates below it need a session so they do not redirect it away. Any
  // other status (anonymous, error, logout) forgets it.
  const [heldSession, setHeldSession] = useState<StaffSessionView | null>(null)

  useEffect(() => {
    const unsubscribe = coordinator.subscribe((next) => {
      setState(next)
      setHeldSession((previous) => {
        if (next.status === 'authenticated') return next.session
        return next.status === 'restoring' || next.status === 'refreshing' ? previous : null
      })
    })
    const stop = coordinator.start()
    return () => {
      unsubscribe()
      stop()
    }
  }, [coordinator])

  // The actions depend only on the coordinator, so their identities survive every state change
  // (including the periodic re-confirmation); effects that list them do not re-run or refetch.
  const actions = useMemo<Omit<StaffAuthContextValue, 'state' | 'session'>>(() => ({
    login: (email, password) => coordinator.login(email, password),
    logout: () => coordinator.logout(),
    retry: () => coordinator.retry(),
    retryPendingLogout: () => coordinator.retryPendingLogout(),
    startMfaEnrollment: () => coordinator.startMfaEnrollment(),
    verifyMfa: (code) => coordinator.verifyMfa(code),
    cancelMfa: () => coordinator.cancelMfa(),
    resetMfa: (email, password, proof) => coordinator.resetMfa(email, password, proof),
  }), [coordinator])

  const value = useMemo<StaffAuthContextValue>(() => ({
    ...actions,
    state,
    session: state.status === 'authenticated' ? state.session : state.status === 'restoring' || state.status === 'refreshing' ? heldSession : null,
  }), [actions, state, heldSession])

  return <StaffAuthContext.Provider value={value}>{children}</StaffAuthContext.Provider>
}
