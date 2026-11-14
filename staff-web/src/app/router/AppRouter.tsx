import { BrowserRouter, Route, Routes } from 'react-router'
import { StaffLayout } from '../layouts/StaffLayout'
import { SignInPage } from '../../features/auth/SignInPage'
import { AuditWorkspacePage } from '../../features/audit/AuditWorkspacePage'
import { NotFoundPage } from '../../features/shared/NotFoundPage'
import { SupportWorkspacePage } from '../../features/support/SupportWorkspacePage'
import { StaffAuthProvider } from '../../shared/auth/StaffAuthProvider'
import { RequireStaffSession } from './RequireStaffSession'
import { RequireStaffRole, RoleHomeRedirect } from './RequireStaffRole'
import { StaffThemeProvider } from '../../shared/theme/StaffThemeProvider'

export function AppRouter() {
  return (
    <StaffThemeProvider>
      <StaffAuthProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<SignInPage />} path="/login" />
            <Route element={<RequireStaffSession><StaffLayout /></RequireStaffSession>} path="/">
              <Route element={<RoleHomeRedirect />} index />
              <Route element={<RequireStaffRole role="support_agent"><SupportWorkspacePage /></RequireStaffRole>} path="support/*" />
              <Route element={<RequireStaffRole role="security_auditor"><AuditWorkspacePage /></RequireStaffRole>} path="audit/*" />
            </Route>
            <Route element={<NotFoundPage />} path="*" />
          </Routes>
        </BrowserRouter>
      </StaffAuthProvider>
    </StaffThemeProvider>
  )
}
