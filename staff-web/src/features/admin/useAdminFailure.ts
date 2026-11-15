import { useCallback } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { needsSessionCheck, safeAdminDiagnostic, safeAdminMessage, type AdminOperation } from './adminApi'
import type { AdminFailure } from './AdminFailureNotice'

/**
 * Converts a failed administrator request into a safe notice and, after a 401 or 403, asks the
 * session coordinator to re-confirm the session: it silently renews an expired access credential,
 * or removes the protected view when the role, account status or MFA assurance is no longer valid.
 * The person keeps whatever they typed and can simply send the action again.
 */
export function useAdminFailure(): (error: unknown, operation: AdminOperation) => AdminFailure {
  const { retry } = useStaffAuth()
  return useCallback(
    (error: unknown, operation: AdminOperation) => {
      if (needsSessionCheck(error)) void retry()
      return { message: safeAdminMessage(error), diagnostic: safeAdminDiagnostic(error, operation) }
    },
    [retry],
  )
}
