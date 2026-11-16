import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['./src/test/setup.ts'],
    clearMocks: true,
    // Coverage instrumentation makes the user-event heavy flows slower than the 5 s default.
    testTimeout: 15_000,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: [
        'src/app/router/AppRouter.tsx',
        'src/app/router/RequireStaffSession.tsx',
        'src/app/router/RequireStaffRole.tsx',
        'src/features/audit/**/*.{ts,tsx}',
        'src/features/admin/**/*.{ts,tsx}',
        'src/features/auth/ActivatePage.tsx',
        'src/features/auth/RecoverPage.tsx',
        'src/features/auth/activationToken.ts',
        'src/features/auth/MfaStep.tsx',
        'src/shared/auth/roleHome.ts',
        'src/app/layouts/StaffLayout.tsx',
        'src/features/auth/SignInPage.tsx',
        'src/features/auth/AuthDiagnosticPanel.tsx',
        'src/features/shared/OverviewPage.tsx',
        'src/shared/api/staffAuthApi.ts',
        'src/shared/auth/StaffAuthProvider.tsx',
        'src/shared/auth/staffAuthContext.ts',
        'src/shared/auth/staffSessionCoordinator.ts',
        'src/shared/auth/useStaffAuth.ts',
        'src/shared/theme/StaffThemeProvider.tsx',
        'src/shared/theme/ThemeToggleButton.tsx',
      ],
      exclude: ['src/**/*.test.{ts,tsx}'],
      thresholds: {
        statements: 80,
        branches: 80,
        functions: 80,
        lines: 80,
      },
    },
  },
})
