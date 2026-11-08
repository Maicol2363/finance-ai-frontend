import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ErrorState, LoadingState } from './AsyncState'

describe('shared async states', () => {
  it('announces loading state to assistive technology', () => {
    render(<LoadingState label="Loading tickets" />)
    expect(screen.getByRole('status')).toHaveTextContent('Loading tickets')
  })

  it('announces safe errors and invokes retry when provided', async () => {
    const user = userEvent.setup()
    const onRetry = vi.fn()
    render(<ErrorState title="The request failed. Try again later." onRetry={onRetry} />)

    expect(screen.getByRole('alert')).toHaveTextContent('The request failed. Try again later.')
    await user.click(screen.getByRole('button', { name: 'Try again' }))
    expect(onRetry).toHaveBeenCalledOnce()
  })
})
