import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router'
import { describe, expect, it, vi } from 'vitest'
import { NotFoundPage } from './NotFoundPage'

function renderNotFound(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route element={<NotFoundPage />} path="*" />
      </Routes>
    </MemoryRouter>,
  )
}

function installClipboard(writeText: Clipboard['writeText']) {
  const previous = Object.getOwnPropertyDescriptor(navigator, 'clipboard')
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: { writeText },
  })
  return () => {
    if (previous) {
      Object.defineProperty(navigator, 'clipboard', previous)
    } else {
      Reflect.deleteProperty(navigator, 'clipboard')
    }
  }
}

describe('not-found diagnostics', () => {
  it('copies a stable report without the unmatched URL or query values', async () => {
    const writeText = vi.fn<Clipboard['writeText']>().mockResolvedValue()
    const restoreClipboard = installClipboard(writeText)

    try {
      renderNotFound('/private/customer/812?email=hidden%40example.com&token=secret-value')

      expect(screen.getByRole('heading', { name: 'No encontramos esta página' })).toBeInTheDocument()
      expect(screen.getByText('route_not_found')).toBeInTheDocument()
      const report = screen.getByLabelText('Contenido del informe de diagnóstico').textContent ?? ''
      expect(report).toContain('Código de error: route_not_found')
      expect(report).toContain('Operación: route.not_found')
      expect(report).toContain('Plataforma: web')
      expect(report).not.toContain('/private/customer/812')
      expect(report).not.toContain('hidden@example.com')
      expect(report).not.toContain('secret-value')

      fireEvent.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))

      expect(writeText).toHaveBeenCalledExactlyOnceWith(report)
      expect(await screen.findByRole('status')).toHaveTextContent('Se copió el informe de diagnóstico.')
    } finally {
      restoreClipboard()
    }
  })

  it('keeps the report selectable when the browser clipboard is unavailable', async () => {
    const restoreClipboard = installClipboard(vi.fn().mockRejectedValue(new Error('private clipboard detail')))

    try {
      renderNotFound('/unmatched?private=value')
      fireEvent.click(screen.getByRole('button', { name: 'Copiar informe de diagnóstico' }))

      expect(await screen.findByRole('status')).toHaveTextContent(
        'No se puede copiar aquí. Selecciona y copia el informe de arriba.',
      )
      expect(screen.getByLabelText('Contenido del informe de diagnóstico')).toHaveTextContent('route_not_found')
      expect(screen.getByLabelText('Contenido del informe de diagnóstico')).not.toHaveTextContent('private=value')
      expect(screen.getByLabelText('Contenido del informe de diagnóstico')).not.toHaveTextContent('private clipboard detail')
    } finally {
      restoreClipboard()
    }
  })
})
