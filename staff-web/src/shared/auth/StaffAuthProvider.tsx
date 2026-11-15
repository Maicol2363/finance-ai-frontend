import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { StaffSessionCoordinator, type StaffAuthState } from './staffSessionCoordinator'
import { StaffAuthContext, type StaffAuthContextValue } from './staffAuthContext'

interface StaffAuthProviderProps {
  children: ReactNode
}

export function StaffAuthProvider({ children }: StaffAuthProviderProps) {
  const [coordinator] = useState(() => new StaffSessionCoordinator())
  const [state, setState] = useState<StaffAuthState>(coordinator.currentState)

  useEffect(() => {
    const unsubscribe = coordinator.subscribe(setState)
    const stop = coordinator.start()
    return () => {
      unsubscribe()
      stop()
    }
  }, [coordinator])

  const value = useMemo<StaffAuthContextValue>(() => ({
    state,
    login: (email, password) => coordinator.login(email, password),
    logout: () => coordinator.logout(),
    retry: () => coordinator.retry(),
    retryPendingLogout: () => coordinator.retryPendingLogout(),
    session: state.status === 'authenticated' ? state.session : null,
  }), [coordinator, state])

  return <StaffAuthContext.Provider value={value}>{children}</StaffAuthContext.Provider>
}
