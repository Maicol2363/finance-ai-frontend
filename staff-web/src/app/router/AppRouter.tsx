import { BrowserRouter, Navigate, Route, Routes } from 'react-router'
import { StaffLayout } from '../layouts/StaffLayout'
import { SignInPage } from '../../features/auth/SignInPage'
import { NotFoundPage } from '../../features/shared/NotFoundPage'
import { SupportWorkspacePage } from '../../features/support/SupportWorkspacePage'
import { StaffAuthProvider } from '../../shared/auth/StaffAuthProvider'
import { RequireStaffSession } from './RequireStaffSession'
import { StaffThemeProvider } from '../../shared/theme/StaffThemeProvider'

export function AppRouter() {
  return (
    <StaffThemeProvider>
      <StaffAuthProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<SignInPage />} path="/login" />
            <Route element={<RequireStaffSession><StaffLayout /></RequireStaffSession>} path="/">
              <Route element={<Navigate to="/support" replace />} index />
              <Route element={<SupportWorkspacePage />} path="support/*" />
            </Route>
            <Route element={<NotFoundPage />} path="*" />
          </Routes>
        </BrowserRouter>
      </StaffAuthProvider>
    </StaffThemeProvider>
  )
}
