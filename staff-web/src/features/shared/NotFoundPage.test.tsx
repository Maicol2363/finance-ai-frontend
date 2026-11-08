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

      expect(screen.getByRole('heading', { name: 'That page is not here' })).toBeInTheDocument()
      expect(screen.getByText('route_not_found')).toBeInTheDocument()
      const report = screen.getByLabelText('Diagnostic report').textContent ?? ''
      expect(report).toContain('Error code: route_not_found')
      expect(report).toContain('Operation: route.not_found')
      expect(report).toContain('Platform: web')
      expect(report).not.toContain('/private/customer/812')
      expect(report).not.toContain('hidden@example.com')
      expect(report).not.toContain('secret-value')

      fireEvent.click(screen.getByRole('button', { name: 'Copy diagnostic report' }))

      expect(writeText).toHaveBeenCalledExactlyOnceWith(report)
      expect(await screen.findByRole('status')).toHaveTextContent('Diagnostic report copied.')
    } finally {
      restoreClipboard()
    }
  })

  it('keeps the report selectable when the browser clipboard is unavailable', async () => {
    const restoreClipboard = installClipboard(vi.fn().mockRejectedValue(new Error('private clipboard detail')))

    try {
      renderNotFound('/unmatched?private=value')
      fireEvent.click(screen.getByRole('button', { name: 'Copy diagnostic report' }))

      expect(await screen.findByRole('status')).toHaveTextContent(
        'Copy is unavailable here. Select and copy the report above.',
      )
      expect(screen.getByLabelText('Diagnostic report')).toHaveTextContent('route_not_found')
      expect(screen.getByLabelText('Diagnostic report')).not.toHaveTextContent('private=value')
      expect(screen.getByLabelText('Diagnostic report')).not.toHaveTextContent('private clipboard detail')
    } finally {
      restoreClipboard()
    }
  })
})
