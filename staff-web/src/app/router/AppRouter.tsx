import { BrowserRouter, Route, Routes } from 'react-router'
import { StaffLayout } from '../layouts/StaffLayout'
import { SignInPage } from '../../features/auth/SignInPage'
import { AdminWorkspacePage } from '../../features/admin/AdminWorkspacePage'
import { AuditWorkspacePage } from '../../features/audit/AuditWorkspacePage'
import { NotFoundPage } from '../../features/shared/NotFoundPage'
import { OverviewPage } from '../../features/shared/OverviewPage'
import { UnauthorizedPage } from '../../features/shared/UnauthorizedPage'
import { SupportWorkspacePage } from '../../features/support/SupportWorkspacePage'

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<StaffLayout />} path="/">
          <Route element={<OverviewPage />} index />
          <Route element={<SignInPage />} path="login" />
          <Route element={<SupportWorkspacePage />} path="support/*" />
          <Route element={<AdminWorkspacePage />} path="admin/*" />
          <Route element={<AuditWorkspacePage />} path="audit/*" />
          <Route element={<UnauthorizedPage />} path="unauthorized" />
          <Route element={<NotFoundPage />} path="*" />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
