import { afterEach, describe, expect, it, vi } from 'vitest'
import { StaffAuthApiError, type StaffSessionView } from '../api/staffAuthApi'
import { StaffSessionCoordinator } from './staffSessionCoordinator'

const sessionView: StaffSessionView = {
  user: { id: 5, email: 'agent@example.test', role: 'support_agent' },
  access_expires_at: '2026-11-12T12:00:00Z',
  renewable_expires_at: '2026-11-12T12:30:00Z',
  absolute_expires_at: '2026-11-12T20:00:00Z',
}

function createStorage(initial: string | null = null) {
  let value = initial
  return {
    getItem: vi.fn(() => value),
    setItem: vi.fn((_key: string, nextValue: string) => { value = nextValue }),
    removeItem: vi.fn(() => { value = null }),
    current: () => value,
  } as unknown as Storage & { current: () => string | null }
}

function createChannel() {
  let messageListener: ((event: MessageEvent<unknown>) => void) | null = null
  return {
    channel: {
      addEventListener: vi.fn((_type: string, listener: EventListenerOrEventListenerObject) => {
        messageListener = listener as (event: MessageEvent<unknown>) => void
      }),
      removeEventListener: vi.fn(),
      postMessage: vi.fn(),
      close: vi.fn(),
    } as unknown as BroadcastChannel,
    send: (data: unknown) => messageListener?.({ data } as MessageEvent<unknown>),
  }
}

function createApi(overrides: Record<string, unknown> = {}) {
  return {
    login: vi.fn().mockResolvedValue(sessionView),
    session: vi.fn().mockResolvedValue(sessionView),
    refresh: vi.fn().mockResolvedValue(sessionView),
    logout: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  }
}

afterEach(() => {
  vi.useRealTimers()
  vi.restoreAllMocks()
})

describe('StaffSessionCoordinator', () => {
  it('restores a server-confirmed support-agent session on startup', async () => {
    const api = createApi()
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null })

    coordinator.start()
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('authenticated'))

    expect(api.session).toHaveBeenCalledOnce()
    expect(coordinator.currentState).toMatchObject({ status: 'authenticated', session: sessionView })
    coordinator.stop()
  })

  it('coalesces concurrent session revalidation requests', async () => {
    let finishSession: ((value: StaffSessionView) => void) | undefined
    const api = createApi({
      session: vi.fn(() => new Promise<StaffSessionView>((resolve) => { finishSession = resolve })),
    })
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null })

    const first = coordinator.restore()
    const second = coordinator.restore()
    await vi.waitFor(() => expect(api.session).toHaveBeenCalledOnce())
    finishSession?.(sessionView)
    await Promise.all([first, second])

    expect(api.session).toHaveBeenCalledOnce()
    expect(coordinator.currentState.status).toBe('authenticated')
    coordinator.stop()
  })

  it('does not restore protected access when a stale session check finishes after logout', async () => {
    let finishSession: ((value: StaffSessionView) => void) | undefined
    const api = createApi({
      session: vi.fn(() => new Promise<StaffSessionView>((resolve) => { finishSession = resolve })),
    })
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null })
    const restore = coordinator.restore()
    await vi.waitFor(() => expect(api.session).toHaveBeenCalledOnce())

    await coordinator.logout()
    finishSession?.(sessionView)
    await restore

    expect(coordinator.currentState.status).toBe('anonymous')
    coordinator.stop()
  })

  it('shares one in-flight refresh promise within a tab', async () => {
    let completeRefresh: ((value: StaffSessionView) => void) | undefined
    const api = createApi({
      session: vi.fn().mockRejectedValue(new StaffAuthApiError(401, 'access_expired')),
      refresh: vi.fn(
        () => new Promise<StaffSessionView>((resolve) => { completeRefresh = resolve }),
      ),
    })
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null })

    const firstRestore = coordinator.restore()
    const secondRestore = coordinator.restore()
    await vi.waitFor(() => expect(api.refresh).toHaveBeenCalledOnce())
    completeRefresh?.(sessionView)
    await Promise.all([firstRestore, secondRestore])

    expect(api.refresh).toHaveBeenCalledOnce()
    expect(coordinator.currentState.status).toBe('authenticated')
    coordinator.stop()
  })

  it('rechecks the session under a Web Lock before rotating the refresh cookie', async () => {
    const request = vi.fn(async (_name: string, _options: unknown, callback: () => Promise<StaffSessionView>) => callback())
    const locks = { request } as unknown as LockManager
    const api = createApi({
      session: vi.fn()
        .mockRejectedValueOnce(new StaffAuthApiError(401, 'access_expired'))
        .mockRejectedValueOnce(new StaffAuthApiError(401, 'authentication_required')),
    })
    const coordinator = new StaffSessionCoordinator(api as never, { locks, channelFactory: null })

    await coordinator.restore()

    expect(request).toHaveBeenCalledWith('finance-ai-staff-refresh', { mode: 'exclusive' }, expect.any(Function))
    expect(api.session).toHaveBeenCalledTimes(2)
    expect(api.refresh).toHaveBeenCalledOnce()
    expect(coordinator.currentState.status).toBe('authenticated')
    coordinator.stop()
  })

  it('pauses the 30-second revalidation while hidden and checks immediately when visible', async () => {
    vi.useFakeTimers()
    let visibility: DocumentVisibilityState = 'visible'
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      get: () => visibility,
    })
    const api = createApi()
    const coordinator = new StaffSessionCoordinator(api as never, { document, channelFactory: null })
    coordinator.start()
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('authenticated'))

    visibility = 'hidden'
    document.dispatchEvent(new Event('visibilitychange'))
    await vi.advanceTimersByTimeAsync(30_000)
    expect(api.session).toHaveBeenCalledOnce()

    visibility = 'visible'
    document.dispatchEvent(new Event('visibilitychange'))
    await vi.waitFor(() => expect(api.session).toHaveBeenCalledTimes(2))
    coordinator.stop()
  })

  it('hides an authenticated view while the timed revalidation is unresolved', async () => {
    vi.useFakeTimers()
    let finishRevalidation: ((value: StaffSessionView) => void) | undefined
    const api = createApi({
      session: vi.fn()
        .mockResolvedValueOnce(sessionView)
        .mockImplementationOnce(() => new Promise<StaffSessionView>((resolve) => { finishRevalidation = resolve })),
    })
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null })
    coordinator.start()
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('authenticated'))

    const revalidation = vi.advanceTimersByTimeAsync(30_000)
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('restoring'))
    finishRevalidation?.(sessionView)
    await revalidation

    expect(coordinator.currentState.status).toBe('authenticated')
    coordinator.stop()
  })

  it('removes the protected view after the current session is definitively denied', async () => {
    vi.useFakeTimers()
    const api = createApi({
      session: vi.fn()
        .mockResolvedValueOnce(sessionView)
        .mockRejectedValueOnce(new StaffAuthApiError(403, 'staff_access_denied')),
    })
    const coordinator = new StaffSessionCoordinator(api as never, { channelFactory: null })
    coordinator.start()
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('authenticated'))

    await vi.advanceTimersByTimeAsync(30_000)

    expect(coordinator.currentState.status).toBe('anonymous')
    coordinator.stop()
  })

  it('keeps ambiguous logout blocked and persists only the pending marker until confirmed', async () => {
    const storage = createStorage()
    const channel = createChannel()
    const api = createApi({ logout: vi.fn().mockRejectedValue(new StaffAuthApiError(0, 'network_error')) })
    const coordinator = new StaffSessionCoordinator(api as never, {
      storage,
      channelFactory: () => channel.channel,
    })
    coordinator.start()
    await vi.waitFor(() => expect(coordinator.currentState.status).toBe('authenticated'))

    await coordinator.logout()

    expect(coordinator.currentState.status).toBe('logout_pending')
    expect(storage.setItem).toHaveBeenCalledWith('finance-ai-staff-logout-pending', '1')
    expect(storage.current()).toBe('1')
    expect(channel.channel.postMessage).not.toHaveBeenCalled()

    vi.mocked(api.logout).mockResolvedValue(undefined)
    await coordinator.retryPendingLogout()

    expect(coordinator.currentState).toMatchObject({ status: 'anonymous', message: 'You are signed out.' })
    expect(storage.removeItem).toHaveBeenCalledWith('finance-ai-staff-logout-pending')
    expect(channel.channel.postMessage).toHaveBeenCalledWith({ type: 'clear-protected-view' })
    coordinator.stop()
  })

  it('does not restore while a logout marker exists and ignores identity-bearing broadcasts', async () => {
    const storage = createStorage('1')
    const api = createApi()
    const channel = createChannel()
    const coordinator = new StaffSessionCoordinator(api as never, {
      storage,
      channelFactory: () => channel.channel,
    })
    coordinator.start()

    expect(coordinator.currentState.status).toBe('logout_pending')
    expect(api.session).not.toHaveBeenCalled()
    channel.send({ type: 'clear-protected-view', email: 'private@example.test' })
    expect(coordinator.currentState.status).toBe('logout_pending')
    channel.send({ type: 'clear-protected-view' })
    expect(coordinator.currentState.status).toBe('anonymous')
    coordinator.stop()
  })
})
