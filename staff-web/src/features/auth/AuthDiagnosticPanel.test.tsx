import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { safeStaffAuthDiagnostic } from '../../shared/auth/staffSessionCoordinator'
import { StaffAuthApiError } from '../../shared/api/staffAuthApi'
import { AuthDiagnosticPanel } from './AuthDiagnosticPanel'

describe('AuthDiagnosticPanel', () => {
  afterEach(() => vi.restoreAllMocks())

  it('copies only fixed, allow-listed diagnostic fields', async () => {
    const writeText = vi.fn<Clipboard['writeText']>().mockResolvedValue()
    const previous = Object.getOwnPropertyDescriptor(navigator, 'clipboard')
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })
    const diagnostic = safeStaffAuthDiagnostic(
      new StaffAuthApiError(401, 'invalid_credentials', 'login-123', null, 'login'),
      'login',
      new Date('2026-11-12T15:30:00.000Z'),
    )

    try {
      render(<AuthDiagnosticPanel diagnostic={diagnostic} />)

      const reportElement = screen.getByLabelText('Contenido del informe de diagnóstico')
      const report = reportElement.textContent ?? ''
      expect(report).toContain('Código del error: invalid_credentials')
      expect(report).toContain('Operación: staff.auth.login')
      expect(report).toContain('Hora UTC: 2026-11-12T15:30:00.000Z')
      expect(report).toContain('Plataforma: web')
      expect(report).toContain('Ubicación de la API: /api/v1/staff/auth/login')
      expect(report).toContain('Id. de solicitud/correlación: login-123')
      expect(report).toContain('Motivo: credentials_rejected')
      expect(report).not.toMatch(/agent@example\.test|not-persisted-password|access_token|raw-body|private-detail/i)

      fireEvent.click(screen.getByTestId('staff-auth-diagnostic-copy-button'))
      expect(writeText).toHaveBeenCalledExactlyOnceWith(report)
      expect(await screen.findByRole('status')).toHaveTextContent('Se copió el informe de diagnóstico.')
    } finally {
      if (previous) Object.defineProperty(navigator, 'clipboard', previous)
      else Reflect.deleteProperty(navigator, 'clipboard')
    }
  })

  it('keeps the report selectable when clipboard access is unavailable', async () => {
    const previous = Object.getOwnPropertyDescriptor(navigator, 'clipboard')
    Reflect.deleteProperty(navigator, 'clipboard')
    const diagnostic = safeStaffAuthDiagnostic(null, 'session', new Date('2026-11-12T15:30:00.000Z'))

    try {
      render(<AuthDiagnosticPanel diagnostic={diagnostic} />)
      fireEvent.click(screen.getByTestId('staff-auth-diagnostic-copy-button'))

      expect(await screen.findByRole('status')).toHaveTextContent(
        'No se puede copiar aquí. Selecciona y copia el informe de arriba.',
      )
      expect(screen.getByLabelText('Contenido del informe de diagnóstico')).toHaveTextContent('unclassified_error')
    } finally {
      if (previous) Object.defineProperty(navigator, 'clipboard', previous)
    }
  })
})
