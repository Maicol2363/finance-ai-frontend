import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ErrorState, LoadingState } from './AsyncState'

describe('shared async states', () => {
  it('announces loading state to assistive technology', () => {
    render(<LoadingState label="Cargando tickets" />)
    expect(screen.getByRole('status')).toHaveTextContent('Cargando tickets')
  })

  it('announces safe errors and invokes retry when provided', async () => {
    const user = userEvent.setup()
    const onRetry = vi.fn()
    render(<ErrorState title="La solicitud falló. Vuelve a intentarlo." onRetry={onRetry} />)

    expect(screen.getByRole('alert')).toHaveTextContent('La solicitud falló. Vuelve a intentarlo.')
    await user.click(screen.getByRole('button', { name: 'Intentar de nuevo' }))
    expect(onRetry).toHaveBeenCalledOnce()
  })
})
