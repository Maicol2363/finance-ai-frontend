import {
  StaffAuthApiError,
  staffAuthApi,
  type StaffAuthOperation,
  type StaffSessionView,
} from '../api/staffAuthApi'

const PENDING_LOGOUT_MARKER = 'finance-ai-staff-logout-pending'
const AUTH_CHANNEL_NAME = 'finance-ai-staff-auth'
const REFRESH_LOCK_NAME = 'finance-ai-staff-refresh'
const REVALIDATION_INTERVAL_MS = 30_000
const DIAGNOSTIC_API_PATH = '/api/v1/staff/auth'
const SAFE_DIAGNOSTIC_CODES = new Set([
  'access_expired',
  'authentication_required',
  'internal_error',
  'invalid_credentials',
  'invalid_response',
  'logout_unconfirmed',
  'network_error',
  'request_timeout',
  'request_too_large',
  'service_unavailable',
  'session_invalid',
  'staff_access_denied',
  'staff_origin_denied',
  'staff_request_denied',
  'staff_session_exists',
  'unknown_error',
  'unclassified_error',
  'unsupported_media_type',
  'validation_error',
])
const SAFE_DIAGNOSTIC_REASONS: Record<string, string> = {
  access_expired: 'access_expired',
  authentication_required: 'authentication_required',
  internal_error: 'server_error',
  invalid_credentials: 'credentials_rejected',
  invalid_response: 'invalid_server_response',
  logout_unconfirmed: 'logout_unconfirmed',
  network_error: 'network_unavailable',
  request_timeout: 'request_timed_out',
  request_too_large: 'request_rejected',
  service_unavailable: 'service_unavailable',
  session_invalid: 'session_invalid',
  staff_access_denied: 'staff_access_denied',
  staff_origin_denied: 'request_origin_denied',
  staff_request_denied: 'request_denied',
  staff_session_exists: 'staff_session_exists',
  unknown_error: 'unknown_error',
  unclassified_error: 'unclassified_error',
  unsupported_media_type: 'unsupported_request_format',
  validation_error: 'request_validation_failed',
}
const SAFE_CORRELATION_ID = /^[A-Za-z0-9._-]{1,64}$/

export interface StaffAuthDiagnostic {
  code: string
  operation: StaffAuthOperation
  occurredAtUtc: string
  platform: 'web'
  apiLocation: string
  correlationId: string | null
  reason: string
}

type SessionApi = Pick<typeof staffAuthApi, 'login' | 'session' | 'refresh' | 'logout'>
type AuthMessage = { type: 'clear-protected-view' }

export type StaffAuthState =
  | { status: 'restoring' }
  | { status: 'anonymous'; message?: string; diagnostic?: StaffAuthDiagnostic }
  | { status: 'authenticating' }
  | { status: 'authenticated'; session: StaffSessionView }
  | { status: 'refreshing' }
  | { status: 'recoverable_error'; message: string; retryAfterSeconds?: number; diagnostic?: StaffAuthDiagnostic }
  | { status: 'logout_pending'; message: string; diagnostic?: StaffAuthDiagnostic }

function isStaffAuthOperation(value: unknown): value is StaffAuthOperation {
  return value === 'login' || value === 'session' || value === 'refresh' || value === 'logout'
}

export function safeStaffAuthDiagnostic(
  error: unknown,
  fallbackOperation: StaffAuthOperation,
  occurredAt = new Date(),
): StaffAuthDiagnostic {
  const errorCode = error instanceof StaffAuthApiError ? error.code : 'unclassified_error'
  const code = SAFE_DIAGNOSTIC_CODES.has(errorCode) ? errorCode : 'unknown_error'
  const safeFallbackOperation = isStaffAuthOperation(fallbackOperation) ? fallbackOperation : 'session'
  const operation = error instanceof StaffAuthApiError && isStaffAuthOperation(error.operation)
    ? error.operation
    : safeFallbackOperation
  const candidateCorrelationId = error instanceof StaffAuthApiError ? error.correlationId : null
  const correlationId = candidateCorrelationId && SAFE_CORRELATION_ID.test(candidateCorrelationId)
    ? candidateCorrelationId
    : null
  const validTime = Number.isFinite(occurredAt.getTime()) ? occurredAt : new Date()

  return {
    code,
    operation,
    occurredAtUtc: validTime.toISOString(),
    platform: 'web',
    apiLocation: `${DIAGNOSTIC_API_PATH}/${operation}`,
    correlationId,
    reason: SAFE_DIAGNOSTIC_REASONS[code] ?? SAFE_DIAGNOSTIC_REASONS.unclassified_error,
  }
}

export function safeStaffAuthMessage(
  error: unknown,
  context: 'login' | 'session' | 'logout',
): string {
  if (!(error instanceof StaffAuthApiError)) {
    return 'Ocurrió un error. Inténtalo de nuevo.'
  }
  if (context === 'login' && error.code === 'invalid_credentials') {
    return 'No se pudo verificar el correo electrónico o la contraseña.'
  }
  if (error.code === 'staff_session_exists') {
    return 'Ya hay una sesión del personal activa. Ciérrala allí y vuelve a intentarlo.'
  }
  if (error.code === 'staff_access_denied' || error.code === 'session_invalid') {
    return 'El acceso del personal ya no está disponible. Inicia sesión otra vez si aún tienes autorización.'
  }
  if (error.status === 429 && error.retryAfterSeconds) {
    return `Demasiados intentos. Vuelve a intentarlo en ${error.retryAfterSeconds} segundos.`
  }
  if (error.code === 'request_timeout' || error.code === 'network_error') {
    return 'No se pudo conectar con el servicio. Comprueba tu conexión e inténtalo de nuevo.'
  }
  if (context === 'logout') return 'No se pudo confirmar el cierre de sesión. Vuelve a intentarlo para completarlo.'
  return 'El servicio no está disponible temporalmente. Inténtalo de nuevo.'
}

function shouldRefresh(error: unknown): boolean {
  return (
    error instanceof StaffAuthApiError &&
    error.status === 401 &&
    (error.code === 'access_expired' || error.code === 'authentication_required')
  )
}

function isDefinitiveDenial(error: unknown): boolean {
  return (
    error instanceof StaffAuthApiError &&
    ((error.status === 401 && error.code === 'session_invalid') ||
      (error.status === 403 && error.code === 'staff_access_denied'))
  )
}

function readLogoutPending(storage: Storage | null): boolean {
  try {
    return storage?.getItem(PENDING_LOGOUT_MARKER) === '1'
  } catch {
    return false
  }
}

function writeLogoutPending(storage: Storage | null): void {
  try {
    storage?.setItem(PENDING_LOGOUT_MARKER, '1')
  } catch {
    // Keep the current tab blocked even when browser storage is unavailable.
  }
}

function clearLogoutPending(storage: Storage | null): void {
  try {
    storage?.removeItem(PENDING_LOGOUT_MARKER)
  } catch {
    // A stale marker also keeps the next page load fail-closed.
  }
}

export class StaffSessionCoordinator {
  private state: StaffAuthState = { status: 'restoring' }
  private session: StaffSessionView | null = null
  private readonly listeners = new Set<(state: StaffAuthState) => void>()
  private readonly api: SessionApi
  private readonly documentRef: Document | null
  private readonly storage: Storage | null
  private readonly locks: LockManager | null
  private readonly channelFactory: ((name: string) => BroadcastChannel | null) | null
  private channel: BroadcastChannel | null = null
  private timer: ReturnType<typeof setTimeout> | null = null
  private restorePromise: Promise<void> | null = null
  private refreshPromise: Promise<StaffSessionView> | null = null
  private logoutPromise: Promise<void> | null = null
  private authGeneration = 0
  private logoutPendingInMemory = false
  private started = false

  constructor(
    api: SessionApi = staffAuthApi,
    environment: {
      document?: Document | null
      storage?: Storage | null
      locks?: LockManager | null
      channelFactory?: ((name: string) => BroadcastChannel | null) | null
    } = {},
  ) {
    this.api = api
    this.documentRef = environment.document ?? (typeof document === 'undefined' ? null : document)
    this.storage = environment.storage ?? this.getSessionStorage()
    this.locks = environment.locks ?? this.getLockManager()
    this.channelFactory = environment.channelFactory === null
      ? null
      : environment.channelFactory ?? this.getChannelFactory()
  }

  get currentState(): StaffAuthState {
    return this.state
  }

  subscribe(listener: (state: StaffAuthState) => void): () => void {
    this.listeners.add(listener)
    listener(this.state)
    return () => this.listeners.delete(listener)
  }

  start(): () => void {
    if (!this.started) {
      this.started = true
      this.channel = this.channelFactory?.(AUTH_CHANNEL_NAME) ?? null
      this.channel?.addEventListener('message', this.handleBroadcast)
      this.documentRef?.addEventListener('visibilitychange', this.handleVisibilityChange)
      if (readLogoutPending(this.storage)) {
        this.logoutPendingInMemory = true
        this.setLogoutPendingState(true)
      } else {
        void this.restore()
      }
    }
    return () => this.stop()
  }

  stop(): void {
    this.started = false
    this.clearTimer()
    this.documentRef?.removeEventListener('visibilitychange', this.handleVisibilityChange)
    this.channel?.removeEventListener('message', this.handleBroadcast)
    this.channel?.close()
    this.channel = null
  }

  async login(email: string, password: string): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.setLogoutPendingState(true)
      return
    }
    const generation = ++this.authGeneration
    this.restorePromise = null
    this.clearTimer()
    this.session = null
    this.setState({ status: 'authenticating' })
    try {
      const session = await this.api.login(email, password)
      if (generation === this.authGeneration) this.setAuthenticated(session)
    } catch (error) {
      if (generation !== this.authGeneration) return
      if (isDefinitiveDenial(error) || (error instanceof StaffAuthApiError && error.status === 401)) {
        this.setState({
          status: 'anonymous',
          message: safeStaffAuthMessage(error, 'login'),
          diagnostic: safeStaffAuthDiagnostic(error, 'login'),
        })
        return
      }
      this.setState({
        status: 'recoverable_error',
        message: safeStaffAuthMessage(error, 'login'),
        diagnostic: safeStaffAuthDiagnostic(error, 'login'),
      })
    }
  }

  async restore(): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.clearTimer()
      if (this.state.status !== 'logout_pending') this.setLogoutPendingState(true)
      return
    }
    if (this.restorePromise) return this.restorePromise
    const restore = this.performRestore()
    this.restorePromise = restore
    try {
      await restore
    } finally {
      if (this.restorePromise === restore) this.restorePromise = null
    }
  }

  private async performRestore(): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      this.setLogoutPendingState(true)
      return
    }
    const generation = this.authGeneration
    const hadConfirmedSession = this.session !== null
    this.setState({ status: 'restoring' })
    try {
      const session = await this.api.session()
      if (generation === this.authGeneration && !this.isLogoutPending()) this.setAuthenticated(session)
    } catch (error) {
      if (generation !== this.authGeneration || this.isLogoutPending()) return
      if (shouldRefresh(error)) {
        this.setState({ status: 'refreshing' })
        try {
          const session = await this.coordinateRefresh()
          if (generation === this.authGeneration && !this.isLogoutPending()) this.setAuthenticated(session)
        } catch (refreshError) {
          if (generation !== this.authGeneration || this.isLogoutPending()) return
          this.handleSessionError(refreshError, hadConfirmedSession, 'refresh')
        }
        return
      }
      this.handleSessionError(error, hadConfirmedSession, 'session')
    }
  }

  async retry(): Promise<void> {
    if (this.state.status !== 'logout_pending') {
      await this.restore()
    }
  }

  async logout(): Promise<void> {
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      if (this.state.status !== 'logout_pending') this.setLogoutPendingState(true)
      return
    }
    this.authGeneration += 1
    this.restorePromise = null
    this.clearTimer()
    this.session = null
    this.logoutPendingInMemory = true
    writeLogoutPending(this.storage)
    this.setState({ status: 'logout_pending', message: 'Cerrando sesión…' })
    await this.completeLogout()
  }

  async retryPendingLogout(): Promise<void> {
    if (this.state.status === 'logout_pending' || this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      await this.completeLogout()
    }
  }

  private async completeLogout(): Promise<void> {
    if (!this.logoutPendingInMemory) return
    if (this.logoutPromise) return this.logoutPromise
    if (!readLogoutPending(this.storage)) writeLogoutPending(this.storage)
    const generation = this.authGeneration
    const attempt = (async () => {
      try {
        await this.api.logout()
        if (generation !== this.authGeneration) return
        this.logoutPendingInMemory = false
        clearLogoutPending(this.storage)
        this.session = null
        this.channel?.postMessage({ type: 'clear-protected-view' } satisfies AuthMessage)
        this.setState({ status: 'anonymous', message: 'Has cerrado sesión.' })
      } catch (error) {
        if (generation !== this.authGeneration) return
        this.logoutPendingInMemory = true
        writeLogoutPending(this.storage)
        this.setState({
          status: 'logout_pending',
          message: safeStaffAuthMessage(error, 'logout'),
          diagnostic: safeStaffAuthDiagnostic(error, 'logout'),
        })
      }
    })()
    this.logoutPromise = attempt
    try {
      await attempt
    } finally {
      if (this.logoutPromise === attempt) this.logoutPromise = null
    }
  }

  private async coordinateRefresh(): Promise<StaffSessionView> {
    if (this.refreshPromise) return this.refreshPromise

    const refresh = async (): Promise<StaffSessionView> => {
      if (!this.locks) return this.api.refresh()
      return this.locks.request(REFRESH_LOCK_NAME, { mode: 'exclusive' }, async () => {
        try {
          return await this.api.session()
        } catch (error) {
          if (!shouldRefresh(error)) throw error
          return this.api.refresh()
        }
      })
    }

    this.refreshPromise = refresh()
    try {
      return await this.refreshPromise
    } finally {
      this.refreshPromise = null
    }
  }

  private handleSessionError(
    error: unknown,
    hadConfirmedSession: boolean,
    operation: 'session' | 'refresh',
  ): void {
    if (isDefinitiveDenial(error)) {
      this.session = null
      this.clearTimer()
      this.setState({
        status: 'anonymous',
        message: safeStaffAuthMessage(error, 'session'),
        diagnostic: safeStaffAuthDiagnostic(error, operation),
      })
      return
    }
    const state: StaffAuthState = {
      status: 'recoverable_error',
      message: safeStaffAuthMessage(error, 'session'),
      diagnostic: safeStaffAuthDiagnostic(error, operation),
    }
    if (error instanceof StaffAuthApiError && error.retryAfterSeconds) {
      state.retryAfterSeconds = error.retryAfterSeconds
    }
    this.setState(state)
    if (hadConfirmedSession) this.scheduleRevalidation()
  }

  private setAuthenticated(session: StaffSessionView): void {
    this.session = session
    this.setState({ status: 'authenticated', session })
    this.scheduleRevalidation()
  }

  private setState(state: StaffAuthState): void {
    this.state = state
    for (const listener of this.listeners) listener(state)
  }

  private scheduleRevalidation(): void {
    this.clearTimer()
    if (!this.started || !this.session || this.isLogoutPending() || this.documentRef?.visibilityState === 'hidden') return
    this.timer = setTimeout(() => {
      this.timer = null
      void this.restore()
    }, REVALIDATION_INTERVAL_MS)
  }

  private clearTimer(): void {
    if (this.timer !== null) clearTimeout(this.timer)
    this.timer = null
  }

  private handleVisibilityChange = (): void => {
    if (this.documentRef?.visibilityState === 'hidden') {
      this.clearTimer()
      return
    }
    if (this.isLogoutPending()) {
      this.logoutPendingInMemory = true
      if (this.state.status !== 'logout_pending') this.setLogoutPendingState(true)
      return
    }
    void this.restore()
  }

  private handleBroadcast = (event: MessageEvent<unknown>): void => {
    if (
      !isRecord(event.data) ||
      event.data.type !== 'clear-protected-view' ||
      Object.keys(event.data).length !== 1
    ) {
      return
    }
    this.authGeneration += 1
    this.clearTimer()
    this.logoutPendingInMemory = false
    this.session = null
    clearLogoutPending(this.storage)
    this.setState({ status: 'anonymous' })
  }

  private isLogoutPending(): boolean {
    return this.logoutPendingInMemory || readLogoutPending(this.storage)
  }

  private setLogoutPendingState(hasFailedAttempt: boolean): void {
    this.setState({
      status: 'logout_pending',
      message: 'No se pudo confirmar el cierre de sesión. Vuelve a intentarlo para completarlo.',
      ...(hasFailedAttempt && {
        diagnostic: safeStaffAuthDiagnostic(
          new StaffAuthApiError(0, 'logout_unconfirmed', null, null, 'logout'),
          'logout',
        ),
      }),
    })
  }

  private getSessionStorage(): Storage | null {
    try {
      return typeof sessionStorage === 'undefined' ? null : sessionStorage
    } catch {
      return null
    }
  }

  private getLockManager(): LockManager | null {
    return typeof navigator === 'undefined' ? null : (navigator.locks ?? null)
  }

  private getChannelFactory(): ((name: string) => BroadcastChannel | null) | null {
    return typeof BroadcastChannel === 'undefined' ? null : (name) => new BroadcastChannel(name)
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
