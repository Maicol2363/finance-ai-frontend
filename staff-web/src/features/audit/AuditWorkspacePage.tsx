import { useEffect, useState } from 'react'
import { Link, Navigate, NavLink, Route, Routes } from 'react-router'
import { useStaffAuth } from '../../shared/auth/useStaffAuth'
import { LoadingState } from '../../shared/ui/AsyncState'
import { auditApi, type AuditCatalog } from './auditApi'
import { AuditCatalogContext } from './auditCatalogContext'
import { AuditErrorPanel } from './AuditErrorPanel'
import { AuditEventDetailPage } from './AuditEventDetailPage'
import { AuditEventsPage } from './AuditEventsPage'
import {
  DEFAULT_MAX_QUERY_DAYS,
  DEFAULT_MAX_REPORT_EVENTS,
  needsSessionCheck,
  safeAuditDiagnostic,
  safeAuditMessage,
  type AuditDiagnostic,
} from './auditFormat'
import { AuditInvestigationPage } from './AuditInvestigationPage'
import { AuditReportsPage } from './AuditReportsPage'
import { AuditSummaryPage } from './AuditSummaryPage'
import { isAbort } from './useAuditRequest'

const SECTIONS = [
  { to: 'events', label: 'Eventos' },
  { to: 'investigation', label: 'Investigación' },
  { to: 'summary', label: 'Resumen' },
  { to: 'reports', label: 'Informes' },
] as const

export function AuditWorkspacePage() {
  const { retry } = useStaffAuth()
  const [catalog, setCatalog] = useState<AuditCatalog | null>(null)
  const [failure, setFailure] = useState<{ message: string; diagnostic: AuditDiagnostic } | null>(null)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    setFailure(null)
    auditApi.catalog(controller.signal)
      .then(setCatalog)
      .catch((error: unknown) => {
        if (controller.signal.aborted || isAbort(error)) return
        if (needsSessionCheck(error)) void retry()
        setFailure({
          message: safeAuditMessage(error, { maxDays: DEFAULT_MAX_QUERY_DAYS, maxReportEvents: DEFAULT_MAX_REPORT_EVENTS }),
          diagnostic: safeAuditDiagnostic(error, 'catalog'),
        })
      })
    return () => controller.abort()
  }, [attempt, retry])

  return (
    <section aria-labelledby="audit-title" className="audit-workspace">
      <div className="page-heading">
        <p className="eyebrow">AUDITOR DE SEGURIDAD</p>
        <h1 id="audit-title">Auditoría de seguridad</h1>
      </div>
      <nav aria-label="Secciones de auditoría" className="audit-tabs">
        {SECTIONS.map((section) => (
          <NavLink className={({ isActive }) => `audit-tab${isActive ? ' is-active' : ''}`} key={section.to} to={`/audit/${section.to}`}>
            {section.label}
          </NavLink>
        ))}
      </nav>
      {failure ? (
        <AuditErrorPanel diagnostic={failure.diagnostic} message={failure.message} onRetry={() => setAttempt((value) => value + 1)} />
      ) : catalog === null ? (
        <LoadingState label="Cargando el espacio de auditoría…" />
      ) : (
        <AuditCatalogContext.Provider value={catalog}>
          <Routes>
            <Route element={<Navigate replace to="/audit/events" />} index />
            <Route element={<AuditEventsPage />} path="events" />
            <Route element={<AuditEventDetailPage />} path="events/:eventId" />
            <Route element={<AuditInvestigationPage />} path="investigation" />
            <Route element={<AuditSummaryPage />} path="summary" />
            <Route element={<AuditReportsPage />} path="reports" />
            <Route
              element={(
                <div className="audit-empty">
                  <p>Esta sección de auditoría no existe.</p>
                  <Link className="text-link" to="/audit/events">Ir a eventos</Link>
                </div>
              )}
              path="*"
            />
          </Routes>
        </AuditCatalogContext.Provider>
      )}
    </section>
  )
}
