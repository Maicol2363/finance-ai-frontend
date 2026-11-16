import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { AdminApiError, safeAdminDiagnostic, safeAdminMessage, type AdminOperation } from './adminApi'
import { AdminFailureNotice } from './AdminFailureNotice'
import { eventLabel, formatAdminReport } from './adminFormat'

function failureFor(error: unknown, operation: AdminOperation) {
  return { message: safeAdminMessage(error), diagnostic: safeAdminDiagnostic(error, operation) }
}

function withClipboard<T>(clipboard: { writeText: (text: string) => Promise<void> } | undefined, run: () => Promise<T>): Promise<T> {
  const previous = Object.getOwnPropertyDescriptor(navigator, 'clipboard')
  if (clipboard) Object.defineProperty(navigator, 'clipboard', { configurable: true, value: clipboard })
  else Reflect.deleteProperty(navigator, 'clipboard')
  return run().finally(() => {
    if (previous) Object.defineProperty(navigator, 'clipboard', previous)
    else Reflect.deleteProperty(navigator, 'clipboard')
  })
}

describe('AdminFailureNotice diagnostic report', () => {
  it('shows the code and reference, and copies a report with only the allow-listed fields', async () => {
    const writeText = vi.fn<(text: string) => Promise<void>>().mockResolvedValue()
    const error = new AdminApiError(409, 'admin_self_action_denied', 'corr-123', 'suspend')
    await withClipboard({ writeText }, async () => {
      render(<AdminFailureNotice failure={failureFor(error, 'suspend')} />)

      expect(screen.getByTestId('admin-error')).toHaveTextContent('Código: admin_self_action_denied · Referencia: corr-123')
      fireEvent.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))
      expect(await screen.findByRole('status')).toHaveTextContent('Se copió el informe de diagnóstico.')
    })

    const report = writeText.mock.calls[0][0]
    expect(report).toContain('Código del error: admin_self_action_denied')
    expect(report).toContain('Operación: staff.admin.suspend')
    expect(report).toMatch(/Hora UTC: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
    expect(report).toContain('Plataforma: web')
    expect(report).toContain('Ubicación de la API: /api/v1/staff/admin/accounts/{id}/suspend')
    expect(report).toContain('Estado HTTP: 409')
    expect(report).toContain('Id. de solicitud/correlación: corr-123')
    // The same text is available to read and select.
    expect(screen.getByTestId('admin-error-report')).toHaveTextContent('Operación: staff.admin.suspend')
  })

  it('never puts typed values, emails, ids or secrets in the report', () => {
    const error = new AdminApiError(404, 'account_not_found', 'corr-9', 'lookup')
    const report = formatAdminReport(safeAdminDiagnostic(error, 'lookup'))

    // Data lines only: the closing privacy sentence names what is excluded.
    const lines = report.split(/\r?\n/)
    const data = lines.slice(0, -1).join(' | ')
    expect(data).not.toMatch(/@/)
    expect(data).not.toMatch(/password|token|cookie|Bearer|contraseña/i)
    expect(data).not.toMatch(/\/accounts\/\d/)
    expect(report).toContain('/api/v1/staff/admin/accounts/lookup')
  })

  it('reports a request that never got a response without inventing a status', () => {
    const report = formatAdminReport(safeAdminDiagnostic(new AdminApiError(0, 'network_error', null, 'queue'), 'queue'))

    expect(report).toContain('Estado HTTP: sin_respuesta')
    expect(report).toContain('Id. de solicitud/correlación: no_disponible')
  })

  it('says so when the clipboard is not available and keeps the report readable', async () => {
    await withClipboard(undefined, async () => {
      render(<AdminFailureNotice failure={failureFor(new AdminApiError(500, 'internal_error', 'c-1', 'case'), 'case')} />)

      fireEvent.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))

      expect(await screen.findByRole('status')).toHaveTextContent('No se puede copiar aquí')
      expect(screen.getByTestId('admin-error-report')).toBeInTheDocument()
    })
  })

  it('has a label for the activity written when a suspended administrator releases a case', () => {
    expect(eventLabel('ticket_admin_released')).toBe('Caso liberado al suspender a su administrador')
  })
})
