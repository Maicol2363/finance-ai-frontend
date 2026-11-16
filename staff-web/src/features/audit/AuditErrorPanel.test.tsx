import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { AuditErrorPanel } from './AuditErrorPanel'

const diagnostic = {
  code: 'audit_query_unavailable',
  operation: 'events' as const,
  occurredAtUtc: '2026-11-14T20:00:00.000Z',
  correlationId: 'corr-1',
}

describe('AuditErrorPanel', () => {
  afterEach(() => vi.restoreAllMocks())

  it('copies a privacy-safe diagnostic report', async () => {
    const user = userEvent.setup()
    const writeText = vi.spyOn(navigator.clipboard, 'writeText').mockResolvedValue(undefined)
    const retry = vi.fn()
    render(<AuditErrorPanel diagnostic={diagnostic} message="No se pudieron consultar los eventos." onRetry={retry} />)

    expect(screen.getByRole('alert')).toHaveTextContent('No se pudieron consultar los eventos.')
    await user.click(screen.getByRole('button', { name: 'Reintentar' }))
    expect(retry).toHaveBeenCalledOnce()
    await user.click(screen.getByText(/Diagnóstico técnico/))
    await user.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))
    expect(writeText).toHaveBeenCalledOnce()
    const report = writeText.mock.calls[0]?.[0] ?? ''
    expect(report).toContain('staff.audit.events')
    expect(report).toContain('corr-1')
    expect(report).not.toMatch(/actor|correlation_id=|password/i)
    expect(await screen.findByText('Se copió el informe de diagnóstico.')).toBeInTheDocument()
  })

  it('explains when the clipboard is unavailable', async () => {
    const user = userEvent.setup()
    vi.spyOn(navigator.clipboard, 'writeText').mockRejectedValue(new Error('denied'))
    render(<AuditErrorPanel diagnostic={{ ...diagnostic, correlationId: null }} message="Error" />)
    expect(screen.queryByRole('button', { name: 'Reintentar' })).not.toBeInTheDocument()
    await user.click(screen.getByText(/Diagnóstico técnico/))
    expect(screen.getByLabelText('Contenido del informe de diagnóstico de auditoría')).toHaveTextContent('no_disponible')
    await user.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))
    expect(await screen.findByText('No se puede copiar aquí. Selecciona y copia el informe.')).toBeInTheDocument()
  })
})
