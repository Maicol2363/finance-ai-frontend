import { render } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { useStaffAuth } from './useStaffAuth'

function AuthConsumer() {
  useStaffAuth()
  return null
}

describe('useStaffAuth', () => {
  it('fails clearly when used outside the provider', () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {})

    expect(() => render(<AuthConsumer />)).toThrow('useStaffAuth must be used within StaffAuthProvider.')

    consoleError.mockRestore()
  })
})
