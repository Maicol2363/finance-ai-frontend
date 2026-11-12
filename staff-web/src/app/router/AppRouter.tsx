import { BrowserRouter, Route, Routes } from 'react-router'
import { StaffLayout } from '../layouts/StaffLayout'
import { SignInPage } from '../../features/auth/SignInPage'
import { NotFoundPage } from '../../features/shared/NotFoundPage'
import { OverviewPage } from '../../features/shared/OverviewPage'
import { SupportWorkspacePage } from '../../features/support/SupportWorkspacePage'
import { StaffAuthProvider } from '../../shared/auth/StaffAuthProvider'
import { RequireStaffSession } from './RequireStaffSession'

export function AppRouter() {
  return (
    <StaffAuthProvider>
      <BrowserRouter>
        <Routes>
          <Route element={<StaffLayout />} path="/">
            <Route element={<OverviewPage />} index />
            <Route element={<SignInPage />} path="login" />
            <Route element={<RequireStaffSession><SupportWorkspacePage /></RequireStaffSession>} path="support/*" />
            <Route element={<NotFoundPage />} path="*" />
          </Route>
        </Routes>
      </BrowserRouter>
    </StaffAuthProvider>
  )
}
