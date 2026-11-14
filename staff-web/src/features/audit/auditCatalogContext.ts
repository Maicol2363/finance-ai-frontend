import { createContext, useContext, useMemo } from 'react'
import type { AuditCatalog } from './auditApi'

export const AuditCatalogContext = createContext<AuditCatalog | null>(null)

export function useAuditCatalog(): AuditCatalog {
  const catalog = useContext(AuditCatalogContext)
  if (!catalog) throw new Error('useAuditCatalog must be used inside the audit workspace')
  return catalog
}

export function useAuditLimits(): { maxDays: number; maxReportEvents: number } {
  const catalog = useAuditCatalog()
  return useMemo(
    () => ({ maxDays: catalog.max_query_days, maxReportEvents: catalog.max_report_events }),
    [catalog],
  )
}
