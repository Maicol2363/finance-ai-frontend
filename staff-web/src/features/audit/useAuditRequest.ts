import { useCallback } from 'react'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import type { AuditOperation } from './auditApi'
import { useAuditLimits } from './auditCatalogContext'
import { needsSessionCheck, safeAuditDiagnostic, safeAuditMessage, type AuditDiagnostic } from './auditFormat'

export interface AuditFailure {
  message: string
  diagnostic: AuditDiagnostic
}

/**
 * Converts a failed audit request into a safe message and, for 401/403, asks the session
 * coordinator to re-confirm the session (refreshing it, or signing the person out when the
 * Auditor role, account status or MFA assurance is no longer valid).
 */
export function useAuditFailure(): (error: unknown, operation: AuditOperation) => AuditFailure {
  const { retry } = useStaffAuth()
  const limits = useAuditLimits()
  return useCallback((error: unknown, operation: AuditOperation) => {
    if (needsSessionCheck(error)) void retry()
    return { message: safeAuditMessage(error, limits), diagnostic: safeAuditDiagnostic(error, operation) }
  }, [limits, retry])
}

export function isAbort(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError'
}
