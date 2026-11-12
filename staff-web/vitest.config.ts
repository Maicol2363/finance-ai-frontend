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
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: [
        'src/app/router/AppRouter.tsx',
        'src/app/router/RequireStaffSession.tsx',
        'src/app/layouts/StaffLayout.tsx',
        'src/features/auth/SignInPage.tsx',
        'src/features/shared/OverviewPage.tsx',
        'src/shared/api/staffAuthApi.ts',
        'src/shared/auth/StaffAuthProvider.tsx',
        'src/shared/auth/staffAuthContext.ts',
        'src/shared/auth/staffSessionCoordinator.ts',
        'src/shared/auth/useStaffAuth.ts',
      ],
      thresholds: {
        statements: 80,
        branches: 80,
        functions: 80,
        lines: 80,
      },
    },
  },
})
